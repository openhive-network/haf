-- =============================================================================
-- Head Block Views for hive schema
-- =============================================================================
-- These views show all data including reversible blocks.
-- Uses DISTINCT ON pattern for canonical block selection:
-- - For each grouping key, picks the row with highest block_id (newest fork)
-- - Efficient for most queries without requiring specialized indexes
--
-- With the hybrid schema:
--   - blocks: uses block_id (for fork tracking)
--   - transactions: uses block_num (original compact format)
--   - operations: uses id (encoded block_num|seq|type)
--   - account_operations: uses operation_id
--   - accounts: uses block_num
--   - applied_hardforks: uses block_num
-- =============================================================================

-- =============================================================================
-- blocks_view - Uses block_id from blocks table
-- =============================================================================
-- Uses NOT EXISTS pattern for canonical block selection:
-- - Select blocks where no other block exists with same block_num but higher block_id
-- - The block_num correlation allows predicate pushdown for equality queries
-- - Requires hive_blocks_block_num_idx for efficient index scans
CREATE OR REPLACE VIEW hive.blocks_view AS
SELECT
    hafd.block_id_to_num(hb.block_id) AS num,
    hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
    hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
    hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
    hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
    hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
FROM hafd.blocks hb
WHERE NOT EXISTS (
    SELECT 1 FROM hafd.blocks hb2
    WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(hb.block_id)  -- same block_num
      AND hb2.block_id > hb.block_id  -- but newer fork
);

-- =============================================================================
-- transactions_view - For each (block_num, trx_in_block), show highest fork_id version
-- =============================================================================
-- Uses NOT EXISTS pattern for canonical block selection:
-- - Select transactions where no other transaction exists with same (block_num, trx_in_block) but higher block_id
-- - The block_num correlation allows predicate pushdown through the view
-- - Requires hive_transactions_block_id_to_num_idx for efficient index scans
CREATE OR REPLACE VIEW hive.transactions_view AS
SELECT
    hafd.block_id_to_num(ht.block_id) AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
WHERE NOT EXISTS (
    SELECT 1 FROM hafd.transactions ht2
    WHERE hafd.block_id_to_num(ht2.block_id) = hafd.block_id_to_num(ht.block_id)  -- same block_num
      AND ht2.trx_in_block = ht.trx_in_block  -- same trx_in_block
      AND ht2.block_id > ht.block_id  -- but newer fork
);

-- =============================================================================
-- operations_view - For each (block_num, seq_in_block), show highest fork_id version
-- =============================================================================
-- Uses correlated MAX subquery for canonical block selection:
-- - For each operation, find the MAX(block_id) among operations with same key
-- - The block_num correlation allows predicate pushdown through the view
-- - Works efficiently for both equality (WHERE block_num = X) and range (WHERE block_num BETWEEN X AND Y) queries
-- - Requires hive_operations_block_num_id_idx for efficient index scans
CREATE OR REPLACE VIEW hive.operations_view AS
SELECT
    ho.id,
    hafd.operation_id_to_block_num(ho.id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    hafd.operation_id_to_type_id(ho.id) AS op_type_id,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
WHERE ho.block_id = (
    SELECT MAX(ho2.block_id)
    FROM hafd.operations ho2
    WHERE (ho2.id >> 8) = (ho.id >> 8)  -- same operation key (block_num + seq_in_block)
      AND hafd.operation_id_to_block_num(ho2.id) = hafd.operation_id_to_block_num(ho.id)  -- same block_num (enables index)
);

-- =============================================================================
-- operations_view_extended - For each (block_num, seq_in_block), show highest fork_id version with timestamp
-- =============================================================================
-- Uses DISTINCT ON with (id >> 8) which combines block_num and seq_in_block.
-- Note: JOIN with blocks is done after DISTINCT ON selection via subquery.
CREATE OR REPLACE VIEW hive.operations_view_extended AS
SELECT
    ov.id,
    ov.block_num,
    ov.trx_in_block,
    ov.op_pos,
    ov.op_type_id,
    b.created_at AS timestamp,
    ov.body_binary,
    ov.body
FROM hive.operations_view ov
JOIN hafd.blocks b ON b.block_id = (
    SELECT ho.block_id FROM hafd.operations ho WHERE ho.id = ov.id
);

-- =============================================================================
-- account_operations_view - Show account_ops from canonical blocks only
-- For each (account_id, account_op_seq_no), pick highest block_id version
-- =============================================================================
-- Uses NOT EXISTS pattern for canonical block selection:
-- - Select account_operations where no other exists with same key but higher block_id
-- - Also filters to operations from canonical blocks via NOT EXISTS on blocks
CREATE OR REPLACE VIEW hive.account_operations_view AS
SELECT
    hafd.block_id_to_num(hao.block_id) AS block_num,
    hao.account_id,
    hao.transacting_account_id,
    hao.account_op_seq_no,
    ho.id AS operation_id,
    hafd.operation_id_to_type_id(ho.id) AS op_type_id
FROM hafd.account_operations hao
JOIN hafd.operations ho ON ho.block_id = hao.block_id AND hafd.operation_id_to_pos(ho.id) = hao.seq_in_block
WHERE NOT EXISTS (
    -- No account_operation with same key but higher block_id
    SELECT 1 FROM hafd.account_operations hao2
    WHERE hao2.account_id = hao.account_id
      AND hao2.account_op_seq_no = hao.account_op_seq_no
      AND hao2.block_id > hao.block_id
)
AND NOT EXISTS (
    -- Block must be canonical (no block with same block_num but higher block_id)
    SELECT 1 FROM hafd.blocks hb2
    WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(hao.block_id)
      AND hb2.block_id > hao.block_id
);

-- =============================================================================
-- accounts_view - Show accounts from canonical blocks only
-- For each account_id, pick the row with highest block_id from canonical blocks
-- NULL block_id means account was dumped at startup (psql-first-block > 1)
-- =============================================================================
-- Logic:
-- 1. First filter to accounts from canonical blocks (or NULL block_id for initial dump)
-- 2. Then for each account_id, pick the one with highest block_id
-- This ensures we don't pick an account from a non-canonical block
CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT ha.id, ha.name
FROM hafd.accounts ha
WHERE (
    -- Account is from initial dump (always valid)
    ha.block_id IS NULL
    -- OR account is from a canonical block
    OR NOT EXISTS (
        SELECT 1 FROM hafd.blocks hb2
        WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(ha.block_id)
          AND hb2.block_id > ha.block_id
    )
)
AND NOT EXISTS (
    -- No other account row with same id but higher block_id that is ALSO from a canonical block
    SELECT 1 FROM hafd.accounts ha2
    WHERE ha2.id = ha.id
      AND (
          -- ha2 has higher priority than ha
          (ha.block_id IS NULL AND ha2.block_id IS NOT NULL)  -- non-NULL beats NULL
          OR (ha.block_id IS NOT NULL AND ha2.block_id IS NOT NULL AND ha2.block_id > ha.block_id)
      )
      -- AND ha2 is from a canonical block (or initial dump)
      AND (
          ha2.block_id IS NULL
          OR NOT EXISTS (
              SELECT 1 FROM hafd.blocks hb3
              WHERE hafd.block_id_to_num(hb3.block_id) = hafd.block_id_to_num(ha2.block_id)
                AND hb3.block_id > ha2.block_id
          )
      )
);

-- =============================================================================
-- transactions_multisig_view - Show signatures from canonical blocks only
-- =============================================================================
-- Uses NOT EXISTS pattern to filter to canonical blocks only
CREATE OR REPLACE VIEW hive.transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
WHERE NOT EXISTS (
    -- Block must be canonical (no block with same block_num but higher block_id)
    SELECT 1 FROM hafd.blocks hb2
    WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(htm.block_id)
      AND hb2.block_id > htm.block_id
);

-- =============================================================================
-- applied_hardforks_view - Show hardforks from canonical blocks,
-- for each hardfork_num, pick the highest block_id
-- =============================================================================
-- Uses NOT EXISTS pattern for canonical hardfork selection:
-- - For each hardfork_num, select where no other row exists with higher block_id
-- - Also filters to canonical blocks via NOT EXISTS on blocks
CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
SELECT
    hah.hardfork_num,
    hafd.block_id_to_num(hah.block_id) AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
WHERE NOT EXISTS (
    -- No other hardfork row with same hardfork_num but higher block_id
    SELECT 1 FROM hafd.applied_hardforks hah2
    WHERE hah2.hardfork_num = hah.hardfork_num
      AND hah2.block_id > hah.block_id
)
AND NOT EXISTS (
    -- Block must be canonical (no block with same block_num but higher block_id)
    SELECT 1 FROM hafd.blocks hb2
    WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(hah.block_id)
      AND hb2.block_id > hah.block_id
);

-- =============================================================================
-- Irreversible views - Only show data from irreversible blocks
-- A row is irreversible if:
--   1. block_num <= block_id_to_num(consistent_block)
--   2. For that block_num, it has the MAX(fork_id) where fork_id <= block_id_to_fork(consistent_block)
-- Each table needs its own windowing since rows have their own block_ids.
-- =============================================================================

-- Uses NOT EXISTS for canonical selection within irreversible range.
-- Allows predicate pushdown for efficient queries.
CREATE OR REPLACE VIEW hive.irreversible_blocks_view AS
SELECT
    hafd.block_id_to_num(hb.block_id) AS num,
    hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
    hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
    hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
    hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
    hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
FROM hafd.blocks hb
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(hb.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hafd.block_id_to_fork(hb.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
  AND NOT EXISTS (
      SELECT 1 FROM hafd.blocks hb2
      WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(hb.block_id)
        AND hafd.block_id_to_fork(hb2.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
        AND hb2.block_id > hb.block_id
  );

-- Uses NOT EXISTS for canonical selection within irreversible range.
-- Allows predicate pushdown for efficient queries.
CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS
SELECT
    hafd.block_id_to_num(ht.block_id) AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(ht.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hafd.block_id_to_fork(ht.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
  AND NOT EXISTS (
      SELECT 1 FROM hafd.transactions ht2
      WHERE hafd.block_id_to_num(ht2.block_id) = hafd.block_id_to_num(ht.block_id)
        AND ht2.trx_in_block = ht.trx_in_block
        AND hafd.block_id_to_fork(ht2.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
        AND ht2.block_id > ht.block_id
  );

-- Uses correlated MAX subquery for canonical selection within irreversible range.
-- Allows predicate pushdown for efficient range queries.
CREATE OR REPLACE VIEW hive.irreversible_operations_view AS
SELECT
    ho.id,
    hafd.operation_id_to_block_num(ho.id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    hafd.operation_id_to_type_id(ho.id) AS op_type_id,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
CROSS JOIN hafd.hive_state hs
WHERE hafd.operation_id_to_block_num(ho.id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hafd.block_id_to_fork(ho.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
  AND ho.block_id = (
      SELECT MAX(ho2.block_id)
      FROM hafd.operations ho2
      WHERE (ho2.id >> 8) = (ho.id >> 8)
        AND hafd.operation_id_to_block_num(ho2.id) = hafd.operation_id_to_block_num(ho.id)
        AND hafd.block_id_to_fork(ho2.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
  );

-- Uses DISTINCT ON for canonical selection within irreversible range.
CREATE OR REPLACE VIEW hive.irreversible_operations_view_extended AS
SELECT
    ov.id,
    ov.block_num,
    ov.trx_in_block,
    ov.op_pos,
    ov.op_type_id,
    b.created_at AS timestamp,
    ov.body_binary,
    ov.body
FROM hive.irreversible_operations_view ov
JOIN hafd.blocks b ON b.block_id = (
    SELECT ho.block_id FROM hafd.operations ho WHERE ho.id = ov.id
);

-- First filter to canonical blocks in irreversible range, then deduplicate.
CREATE OR REPLACE VIEW hive.irreversible_account_operations_view AS
SELECT DISTINCT ON (hao.account_id, hao.account_op_seq_no)
    hafd.block_id_to_num(hao.block_id) AS block_num,
    hao.account_id,
    hao.transacting_account_id,
    hao.account_op_seq_no,
    ho.id AS operation_id,
    hafd.operation_id_to_type_id(ho.id) AS op_type_id
FROM hafd.account_operations hao
JOIN hafd.operations ho ON ho.block_id = hao.block_id AND hafd.operation_id_to_pos(ho.id) = hao.seq_in_block
WHERE hao.block_id IN (
    -- Canonical block_ids within irreversible range
    SELECT DISTINCT ON (hafd.block_id_to_num(hb.block_id)) hb.block_id
    FROM hafd.blocks hb
    CROSS JOIN hafd.hive_state hs
    WHERE hafd.block_id_to_num(hb.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      AND hafd.block_id_to_fork(hb.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
    ORDER BY hafd.block_id_to_num(hb.block_id), hb.block_id DESC
)
ORDER BY hao.account_id, hao.account_op_seq_no, hao.block_id DESC;

-- First filter to canonical blocks in irreversible range, then deduplicate.
CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS
SELECT DISTINCT ON (ha.id)
    ha.id, ha.name
FROM hafd.accounts ha
WHERE ha.block_id IS NULL  -- Accounts from initial dump (psql-first-block > 1)
   OR ha.block_id IN (
       -- Canonical block_ids within irreversible range
       SELECT DISTINCT ON (hafd.block_id_to_num(hb.block_id)) hb.block_id
       FROM hafd.blocks hb
       CROSS JOIN hafd.hive_state hs
       WHERE hafd.block_id_to_num(hb.block_id) <= hafd.block_id_to_num(hs.consistent_block)
         AND hafd.block_id_to_fork(hb.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
       ORDER BY hafd.block_id_to_num(hb.block_id), hb.block_id DESC
   )
ORDER BY ha.id, ha.block_id DESC NULLS LAST;

-- Filter to canonical blocks in irreversible range.
CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
WHERE htm.block_id IN (
    -- Canonical block_ids within irreversible range
    SELECT DISTINCT ON (hafd.block_id_to_num(hb.block_id)) hb.block_id
    FROM hafd.blocks hb
    CROSS JOIN hafd.hive_state hs
    WHERE hafd.block_id_to_num(hb.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      AND hafd.block_id_to_fork(hb.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
    ORDER BY hafd.block_id_to_num(hb.block_id), hb.block_id DESC
);

-- First filter to canonical blocks in irreversible range, then deduplicate.
CREATE OR REPLACE VIEW hive.irreversible_applied_hardforks_view AS
SELECT DISTINCT ON (hah.hardfork_num)
    hah.hardfork_num,
    hafd.block_id_to_num(hah.block_id) AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
WHERE hah.block_id IN (
    -- Canonical block_ids within irreversible range
    SELECT DISTINCT ON (hafd.block_id_to_num(hb.block_id)) hb.block_id
    FROM hafd.blocks hb
    CROSS JOIN hafd.hive_state hs
    WHERE hafd.block_id_to_num(hb.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      AND hafd.block_id_to_fork(hb.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
    ORDER BY hafd.block_id_to_num(hb.block_id), hb.block_id DESC
)
ORDER BY hah.hardfork_num, hah.block_id DESC;
