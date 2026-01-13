-- =============================================================================
-- Head Block Views for hive schema
-- =============================================================================
-- These views show all data including reversible blocks.
-- Uses NOT EXISTS pattern for efficient ORDER BY DESC LIMIT queries.
-- NOT EXISTS allows early termination when scanning index backward.
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
-- Uses NOT EXISTS to filter to canonical rows (highest block_id per block_num).
-- This enables efficient ORDER BY num DESC LIMIT 1 queries via index backward scan.
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
    WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(hb.block_id)
      AND hb2.block_id > hb.block_id
);

-- =============================================================================
-- transactions_view - For each (block_num, trx_in_block), show highest fork_id version
-- =============================================================================
-- Uses NOT EXISTS for efficient queries.
CREATE OR REPLACE VIEW hive.transactions_view AS
SELECT
    hafd.block_id_to_num(ht.block_id) AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
WHERE NOT EXISTS (
    SELECT 1 FROM hafd.transactions ht2
    WHERE hafd.block_id_to_num(ht2.block_id) = hafd.block_id_to_num(ht.block_id)
      AND ht2.trx_in_block = ht.trx_in_block
      AND ht2.block_id > ht.block_id
);

-- =============================================================================
-- operations_view - For each (block_num, seq_in_block), show highest fork_id version
-- =============================================================================
-- Uses NOT EXISTS for efficient queries.
-- operation_id_to_pos extracts the unique sequence number within a block.
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
WHERE NOT EXISTS (
    SELECT 1 FROM hafd.operations ho2
    WHERE hafd.operation_id_to_block_num(ho2.id) = hafd.operation_id_to_block_num(ho.id)
      AND hafd.operation_id_to_pos(ho2.id) = hafd.operation_id_to_pos(ho.id)
      AND ho2.block_id > ho.block_id
);

-- =============================================================================
-- operations_view_extended - For each (block_num, seq_in_block), show highest fork_id version with timestamp
-- =============================================================================
-- Uses NOT EXISTS for efficient queries.
CREATE OR REPLACE VIEW hive.operations_view_extended AS
SELECT
    ho.id,
    hafd.operation_id_to_block_num(ho.id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    hafd.operation_id_to_type_id(ho.id) AS op_type_id,
    b.created_at AS timestamp,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
JOIN hafd.blocks b ON b.block_id = ho.block_id
WHERE NOT EXISTS (
    SELECT 1 FROM hafd.operations ho2
    WHERE hafd.operation_id_to_block_num(ho2.id) = hafd.operation_id_to_block_num(ho.id)
      AND hafd.operation_id_to_pos(ho2.id) = hafd.operation_id_to_pos(ho.id)
      AND ho2.block_id > ho.block_id
);

-- =============================================================================
-- account_operations_view - Show account_ops from canonical blocks only
-- For each (account_id, account_op_seq_no), pick highest block_id from canonical blocks
-- =============================================================================
-- Uses NOT EXISTS for canonical block check and row selection.
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
    -- No newer version of this block exists (canonical block check)
    SELECT 1 FROM hafd.blocks b2
    WHERE hafd.block_id_to_num(b2.block_id) = hafd.block_id_to_num(hao.block_id)
      AND b2.block_id > hao.block_id
)
AND NOT EXISTS (
    -- No newer version of this account_op exists
    SELECT 1 FROM hafd.account_operations hao2
    WHERE hao2.account_id = hao.account_id
      AND hao2.account_op_seq_no = hao.account_op_seq_no
      AND hao2.block_id > hao.block_id
);

-- =============================================================================
-- accounts_view - Show accounts from visible (canonical) blocks only
-- For each account_id, pick the row with highest block_id from visible blocks
-- NULL block_id means account was dumped at startup (psql-first-block > 1)
-- =============================================================================
-- Uses NOT EXISTS for efficient canonical check.
-- For accounts, we need to:
-- 1. Only show accounts from canonical blocks (highest fork_id for each block_num)
-- 2. For each account_id, pick the one from highest block_id among canonical blocks
CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT ha.id, ha.name
FROM hafd.accounts ha
WHERE (ha.block_id IS NULL  -- Accounts from initial dump
   OR NOT EXISTS (
       -- Account's block must be canonical
       SELECT 1 FROM hafd.blocks b2
       WHERE hafd.block_id_to_num(b2.block_id) = hafd.block_id_to_num(ha.block_id)
         AND b2.block_id > ha.block_id
   ))
AND NOT EXISTS (
    -- No newer version of this account exists in a CANONICAL block
    SELECT 1 FROM hafd.accounts ha2
    WHERE ha2.id = ha.id
      AND ha2.block_id IS NOT NULL
      AND (ha.block_id IS NULL OR ha2.block_id > ha.block_id)
      -- ha2's block must also be canonical
      AND NOT EXISTS (
          SELECT 1 FROM hafd.blocks b3
          WHERE hafd.block_id_to_num(b3.block_id) = hafd.block_id_to_num(ha2.block_id)
            AND b3.block_id > ha2.block_id
      )
);

-- =============================================================================
-- transactions_multisig_view - Show signatures from visible blocks only
-- =============================================================================
-- Uses NOT EXISTS for efficient canonical block check.
CREATE OR REPLACE VIEW hive.transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
WHERE NOT EXISTS (
    SELECT 1 FROM hafd.blocks b2
    WHERE hafd.block_id_to_num(b2.block_id) = hafd.block_id_to_num(htm.block_id)
      AND b2.block_id > htm.block_id
);

-- =============================================================================
-- applied_hardforks_view - Show hardforks from visible blocks,
-- then for each hardfork_num, pick the highest block_id
-- =============================================================================
-- Uses NOT EXISTS for efficient queries.
CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
SELECT
    hah.hardfork_num,
    hafd.block_id_to_num(hah.block_id) AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
WHERE NOT EXISTS (
    -- No newer version of this block exists (canonical block check)
    SELECT 1 FROM hafd.blocks b2
    WHERE hafd.block_id_to_num(b2.block_id) = hafd.block_id_to_num(hah.block_id)
      AND b2.block_id > hah.block_id
)
AND NOT EXISTS (
    -- No newer version of this hardfork exists
    SELECT 1 FROM hafd.applied_hardforks hah2
    WHERE hah2.hardfork_num = hah.hardfork_num
      AND hah2.block_id > hah.block_id
);

-- =============================================================================
-- Irreversible views - Only show data from irreversible blocks
-- A row is irreversible if:
--   1. block_num <= block_id_to_num(consistent_block)
--   2. For that block_num, it has the MAX(fork_id) where fork_id <= block_id_to_fork(consistent_block)
-- Each table needs its own windowing since rows have their own block_ids.
-- =============================================================================

-- Uses NOT EXISTS for efficient queries with irreversibility constraints.
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

-- Uses NOT EXISTS for efficient queries.
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

-- Uses NOT EXISTS for efficient queries.
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
  AND NOT EXISTS (
      SELECT 1 FROM hafd.operations ho2
      WHERE hafd.operation_id_to_block_num(ho2.id) = hafd.operation_id_to_block_num(ho.id)
        AND hafd.operation_id_to_pos(ho2.id) = hafd.operation_id_to_pos(ho.id)
        AND hafd.block_id_to_fork(ho2.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
        AND ho2.block_id > ho.block_id
  );

-- Uses NOT EXISTS for efficient queries.
CREATE OR REPLACE VIEW hive.irreversible_operations_view_extended AS
SELECT
    ho.id,
    hafd.operation_id_to_block_num(ho.id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    hafd.operation_id_to_type_id(ho.id) AS op_type_id,
    b.created_at AS timestamp,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
JOIN hafd.blocks b ON b.block_id = ho.block_id
CROSS JOIN hafd.hive_state hs
WHERE hafd.operation_id_to_block_num(ho.id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hafd.block_id_to_fork(ho.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
  AND NOT EXISTS (
      SELECT 1 FROM hafd.operations ho2
      WHERE hafd.operation_id_to_block_num(ho2.id) = hafd.operation_id_to_block_num(ho.id)
        AND hafd.operation_id_to_pos(ho2.id) = hafd.operation_id_to_pos(ho.id)
        AND hafd.block_id_to_fork(ho2.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
        AND ho2.block_id > ho.block_id
  );

-- Uses NOT EXISTS for efficient queries.
CREATE OR REPLACE VIEW hive.irreversible_account_operations_view AS
SELECT
    hafd.block_id_to_num(hao.block_id) AS block_num,
    hao.account_id,
    hao.transacting_account_id,
    hao.account_op_seq_no,
    ho.id AS operation_id,
    hafd.operation_id_to_type_id(ho.id) AS op_type_id
FROM hafd.account_operations hao
JOIN hafd.operations ho ON ho.block_id = hao.block_id AND hafd.operation_id_to_pos(ho.id) = hao.seq_in_block
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(hao.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hafd.block_id_to_fork(hao.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
  AND NOT EXISTS (
      SELECT 1 FROM hafd.account_operations hao2
      WHERE hao2.account_id = hao.account_id
        AND hao2.account_op_seq_no = hao.account_op_seq_no
        AND hafd.block_id_to_fork(hao2.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
        AND hao2.block_id > hao.block_id
  );

-- Uses NOT EXISTS for efficient queries.
CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS
SELECT ha.id, ha.name
FROM hafd.accounts ha
CROSS JOIN hafd.hive_state hs
WHERE (ha.block_id IS NULL  -- Accounts from initial dump (psql-first-block > 1)
   OR (hafd.block_id_to_num(ha.block_id) <= hafd.block_id_to_num(hs.consistent_block)
       AND hafd.block_id_to_fork(ha.block_id) <= hafd.block_id_to_fork(hs.consistent_block)))
  AND NOT EXISTS (
      SELECT 1 FROM hafd.accounts ha2
      WHERE ha2.id = ha.id
        AND ha2.block_id IS NOT NULL
        AND (ha.block_id IS NULL OR ha2.block_id > ha.block_id)
        AND hafd.block_id_to_fork(ha2.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
  );

-- Uses NOT EXISTS for efficient queries.
CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(htm.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hafd.block_id_to_fork(htm.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
  AND NOT EXISTS (
      SELECT 1 FROM hafd.transactions_multisig htm2
      WHERE htm2.trx_hash = htm.trx_hash
        AND htm2.signature = htm.signature
        AND hafd.block_id_to_fork(htm2.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
        AND htm2.block_id > htm.block_id
  );

-- Uses NOT EXISTS for efficient queries.
CREATE OR REPLACE VIEW hive.irreversible_applied_hardforks_view AS
SELECT
    hah.hardfork_num,
    hafd.block_id_to_num(hah.block_id) AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(hah.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hafd.block_id_to_fork(hah.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
  AND NOT EXISTS (
      SELECT 1 FROM hafd.applied_hardforks hah2
      WHERE hah2.hardfork_num = hah.hardfork_num
        AND hafd.block_id_to_fork(hah2.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
        AND hah2.block_id > hah.block_id
  );
