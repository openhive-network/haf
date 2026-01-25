-- =============================================================================
-- Head Block Views for hive schema
-- =============================================================================
-- These views show all data including reversible blocks.
-- Uses correlated MAX subquery pattern for canonical block selection:
-- - For each grouping key, find MAX(block_id) among rows with same key
-- - Enables predicate pushdown for both equality and range queries
-- - Example: WHERE block_num BETWEEN X AND Y works efficiently
--
-- With the hybrid schema:
--   - blocks: uses block_id (for fork tracking)
--   - transactions: uses block_id (for fork tracking)
--   - operations: uses id (encoded block_num|seq|type) + block_id
--   - account_operations: uses block_id
--   - accounts: uses block_id (NULL for initial dump)
--   - applied_hardforks: uses block_id
-- =============================================================================

-- =============================================================================
-- blocks_view - Uses block_id from blocks table
-- =============================================================================
-- Uses correlated MAX subquery for canonical block selection:
-- - For each block, find the MAX(block_id) among blocks with same block_num
-- - The block_num correlation allows predicate pushdown through the view
-- - Works efficiently for both equality and range queries
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
WHERE hb.block_id = (
    SELECT MAX(hb2.block_id)
    FROM hafd.blocks hb2
    WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(hb.block_id)
);

-- =============================================================================
-- transactions_view - For each (block_num, trx_in_block), show highest fork_id version
-- =============================================================================
-- Uses correlated MAX subquery for canonical block selection:
-- - For each transaction, find the MAX(block_id) among transactions with same key
-- - The block_num correlation allows predicate pushdown through the view
-- - Works efficiently for both equality and range queries
-- - Requires hive_transactions_block_id_to_num_idx for efficient index scans
CREATE OR REPLACE VIEW hive.transactions_view AS
SELECT
    hafd.block_id_to_num(ht.block_id) AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
WHERE ht.block_id = (
    SELECT MAX(ht2.block_id)
    FROM hafd.transactions ht2
    WHERE hafd.block_id_to_num(ht2.block_id) = hafd.block_id_to_num(ht.block_id)
      AND ht2.trx_in_block = ht.trx_in_block
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
-- Uses correlated MAX subquery for canonical block selection:
-- - For each account_operation, find the MAX(block_id) among those with same key
-- - Also filters to canonical blocks via correlated MAX on blocks
-- - Works efficiently for both equality and range queries
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
WHERE hao.block_id = (
    -- Find MAX(block_id) for this (account_id, account_op_seq_no) from canonical blocks only
    SELECT MAX(hao2.block_id)
    FROM hafd.account_operations hao2
    WHERE hao2.account_id = hao.account_id
      AND hao2.account_op_seq_no = hao.account_op_seq_no
      AND hao2.block_id = (
          -- Block must be canonical
          SELECT MAX(hb.block_id) FROM hafd.blocks hb
          WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(hao2.block_id)
      )
);

-- =============================================================================
-- accounts_view - Show accounts from canonical blocks only
-- For each account_id, pick the row with highest block_id from canonical blocks
-- NULL block_id means account was dumped at startup (psql-first-block > 1)
-- =============================================================================
-- Uses correlated MAX subquery for canonical account selection:
-- - For each account_id, find the MAX(block_id) among accounts from canonical blocks
-- - NULL block_id (from initial dump) is treated as lower than any non-NULL block_id
-- - Works efficiently for both equality and range queries
CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT ha.id, ha.name
FROM hafd.accounts ha
WHERE (
    -- Account is from initial dump (always valid) AND no newer version exists
    ha.block_id IS NULL
    AND NOT EXISTS (
        SELECT 1 FROM hafd.accounts ha2
        WHERE ha2.id = ha.id AND ha2.block_id IS NOT NULL
          AND ha2.block_id = (
              SELECT MAX(hb.block_id) FROM hafd.blocks hb
              WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(ha2.block_id)
          )
    )
)
OR (
    -- Account is from a canonical block AND is the highest block_id version
    ha.block_id IS NOT NULL
    AND ha.block_id = (
        SELECT MAX(hb.block_id) FROM hafd.blocks hb
        WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(ha.block_id)
    )
    AND ha.block_id = (
        SELECT MAX(ha2.block_id)
        FROM hafd.accounts ha2
        WHERE ha2.id = ha.id
          AND ha2.block_id IS NOT NULL
          AND ha2.block_id = (
              SELECT MAX(hb.block_id) FROM hafd.blocks hb
              WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(ha2.block_id)
          )
    )
);

-- =============================================================================
-- transactions_multisig_view - Show signatures from canonical blocks only
-- =============================================================================
-- Uses correlated MAX subquery to filter to canonical blocks only
-- Works efficiently for both equality and range queries
CREATE OR REPLACE VIEW hive.transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
WHERE htm.block_id = (
    SELECT MAX(hb.block_id) FROM hafd.blocks hb
    WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(htm.block_id)
);

-- =============================================================================
-- applied_hardforks_view - Show hardforks from canonical blocks,
-- for each hardfork_num, pick the highest block_id
-- =============================================================================
-- Uses correlated MAX subquery for canonical hardfork selection:
-- - For each hardfork_num, find the MAX(block_id) among those from canonical blocks
-- - Works efficiently for both equality and range queries
CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
SELECT
    hah.hardfork_num,
    hafd.block_id_to_num(hah.block_id) AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
WHERE hah.block_id = (
    -- Find MAX(block_id) for this hardfork_num from canonical blocks only
    SELECT MAX(hah2.block_id)
    FROM hafd.applied_hardforks hah2
    WHERE hah2.hardfork_num = hah.hardfork_num
      AND hah2.block_id = (
          -- Block must be canonical
          SELECT MAX(hb.block_id) FROM hafd.blocks hb
          WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(hah2.block_id)
      )
);

-- =============================================================================
-- Irreversible views - Only show data from irreversible blocks
-- Uses NOT EXISTS pattern for canonical selection - fast when only one version
-- exists (typical case), still correct when multiple fork versions exist.
-- =============================================================================

-- NOT EXISTS pattern: keeps row only if no higher fork_id version exists
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
  AND NOT EXISTS (
      SELECT 1 FROM hafd.blocks hb2
      WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(hb.block_id)
        AND hb2.block_id > hb.block_id
        AND hafd.block_id_to_num(hb2.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  );

-- NOT EXISTS pattern for transactions
CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS
SELECT
    hafd.block_id_to_num(ht.block_id) AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(ht.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND NOT EXISTS (
      SELECT 1 FROM hafd.transactions ht2
      WHERE hafd.block_id_to_num(ht2.block_id) = hafd.block_id_to_num(ht.block_id)
        AND ht2.trx_in_block = ht.trx_in_block
        AND ht2.block_id > ht.block_id
        AND hafd.block_id_to_num(ht2.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  );

-- NOT EXISTS pattern for operations - optimized for full table scans
-- Short-circuits quickly when only one version exists (typical case)
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
  AND NOT EXISTS (
      SELECT 1 FROM hafd.operations ho2
      WHERE (ho2.id >> 8) = (ho.id >> 8)
        AND ho2.block_id > ho.block_id
        AND hafd.operation_id_to_block_num(ho2.id) <= hafd.block_id_to_num(hs.consistent_block)
  );

-- Extended operations view with timestamp
CREATE OR REPLACE VIEW hive.irreversible_operations_view_extended AS
SELECT
    ov.id,
    ov.block_num,
    ov.trx_in_block,
    ov.op_pos,
    ov.op_type_id,
    hb.created_at AS timestamp,
    ov.body_binary,
    ov.body
FROM hive.irreversible_operations_view ov
JOIN hafd.blocks hb ON hafd.block_id_to_num(hb.block_id) = ov.block_num
  AND NOT EXISTS (
      SELECT 1 FROM hafd.blocks hb2
      WHERE hafd.block_id_to_num(hb2.block_id) = ov.block_num
        AND hb2.block_id > hb.block_id
  );

-- NOT EXISTS pattern for account_operations
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
  AND NOT EXISTS (
      SELECT 1 FROM hafd.account_operations hao2
      WHERE hao2.account_id = hao.account_id
        AND hao2.account_op_seq_no = hao.account_op_seq_no
        AND hao2.block_id > hao.block_id
        AND hafd.block_id_to_num(hao2.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  );

-- NOT EXISTS pattern for accounts with NULL block_id handling
CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS
SELECT ha.id, ha.name
FROM hafd.accounts ha
CROSS JOIN hafd.hive_state hs
WHERE (
    -- Account is from initial dump AND no newer version exists in irreversible range
    ha.block_id IS NULL
    AND NOT EXISTS (
        SELECT 1 FROM hafd.accounts ha2
        WHERE ha2.id = ha.id AND ha2.block_id IS NOT NULL
          AND hafd.block_id_to_num(ha2.block_id) <= hafd.block_id_to_num(hs.consistent_block)
    )
)
OR (
    -- Account is from an irreversible block AND no higher block_id version exists
    ha.block_id IS NOT NULL
    AND hafd.block_id_to_num(ha.block_id) <= hafd.block_id_to_num(hs.consistent_block)
    AND NOT EXISTS (
        SELECT 1 FROM hafd.accounts ha2
        WHERE ha2.id = ha.id
          AND ha2.block_id IS NOT NULL
          AND ha2.block_id > ha.block_id
          AND hafd.block_id_to_num(ha2.block_id) <= hafd.block_id_to_num(hs.consistent_block)
    )
);

-- NOT EXISTS pattern for transactions_multisig
CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(htm.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND NOT EXISTS (
      SELECT 1 FROM hafd.transactions_multisig htm2
      WHERE htm2.trx_hash = htm.trx_hash
        AND htm2.signature = htm.signature
        AND htm2.block_id > htm.block_id
        AND hafd.block_id_to_num(htm2.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  );

-- NOT EXISTS pattern for applied_hardforks
CREATE OR REPLACE VIEW hive.irreversible_applied_hardforks_view AS
SELECT
    hah.hardfork_num,
    hafd.block_id_to_num(hah.block_id) AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(hah.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND NOT EXISTS (
      SELECT 1 FROM hafd.applied_hardforks hah2
      WHERE hah2.hardfork_num = hah.hardfork_num
        AND hah2.block_id > hah.block_id
        AND hafd.block_id_to_num(hah2.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  );
