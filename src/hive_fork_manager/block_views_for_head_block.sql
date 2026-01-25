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
-- Uses DISTINCT ON to select canonical block per block_num (highest block_id).
CREATE OR REPLACE VIEW hive.blocks_view AS
SELECT DISTINCT ON (hafd.block_id_to_num(hb.block_id))
    hafd.block_id_to_num(hb.block_id) AS num,
    hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
    hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
    hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
    hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
    hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
FROM hafd.blocks hb
ORDER BY hafd.block_id_to_num(hb.block_id), hb.block_id DESC;

-- =============================================================================
-- transactions_view - For each (block_num, trx_in_block), show highest fork_id version
-- =============================================================================
-- Uses DISTINCT ON to select canonical transaction per (block_num, trx_in_block).
CREATE OR REPLACE VIEW hive.transactions_view AS
SELECT DISTINCT ON (hafd.block_id_to_num(ht.block_id), ht.trx_in_block)
    hafd.block_id_to_num(ht.block_id) AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
ORDER BY hafd.block_id_to_num(ht.block_id), ht.trx_in_block, ht.block_id DESC;

-- =============================================================================
-- operations_view - For each (block_num, seq_in_block), show highest fork_id version
-- =============================================================================
-- Uses DISTINCT ON with (id >> 8) which combines block_num and seq_in_block.
CREATE OR REPLACE VIEW hive.operations_view AS
SELECT DISTINCT ON ((ho.id >> 8))
    ho.id,
    hafd.operation_id_to_block_num(ho.id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    hafd.operation_id_to_type_id(ho.id) AS op_type_id,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
ORDER BY (ho.id >> 8), ho.block_id DESC;

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
-- For each (account_id, account_op_seq_no) in canonical blocks, pick highest block_id
-- =============================================================================
-- First filter to canonical blocks, then deduplicate by (account_id, account_op_seq_no).
CREATE OR REPLACE VIEW hive.account_operations_view AS
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
    -- Canonical block_ids: highest block_id per block_num
    SELECT DISTINCT ON (hafd.block_id_to_num(block_id)) block_id
    FROM hafd.blocks
    ORDER BY hafd.block_id_to_num(block_id), block_id DESC
)
ORDER BY hao.account_id, hao.account_op_seq_no, hao.block_id DESC;

-- =============================================================================
-- accounts_view - Show accounts from canonical blocks only
-- For each account_id from canonical blocks, pick the row with highest block_id
-- NULL block_id means account was dumped at startup (psql-first-block > 1)
-- =============================================================================
-- First filter to only canonical blocks, then deduplicate by account id.
CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT DISTINCT ON (ha.id)
    ha.id, ha.name
FROM hafd.accounts ha
WHERE ha.block_id IS NULL  -- Accounts from initial dump
   OR ha.block_id IN (
       -- Canonical block_ids: highest block_id per block_num
       SELECT DISTINCT ON (hafd.block_id_to_num(block_id)) block_id
       FROM hafd.blocks
       ORDER BY hafd.block_id_to_num(block_id), block_id DESC
   )
ORDER BY ha.id, ha.block_id DESC NULLS LAST;

-- =============================================================================
-- transactions_multisig_view - Show signatures from canonical blocks only
-- =============================================================================
-- Filter to only rows from canonical blocks (highest block_id per block_num).
CREATE OR REPLACE VIEW hive.transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
WHERE htm.block_id IN (
    -- Canonical block_ids: highest block_id per block_num
    SELECT DISTINCT ON (hafd.block_id_to_num(block_id)) block_id
    FROM hafd.blocks
    ORDER BY hafd.block_id_to_num(block_id), block_id DESC
);

-- =============================================================================
-- applied_hardforks_view - Show hardforks from canonical blocks,
-- then for each hardfork_num, pick the highest block_id
-- =============================================================================
-- First filter to canonical blocks, then deduplicate by hardfork_num.
CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
SELECT DISTINCT ON (hah.hardfork_num)
    hah.hardfork_num,
    hafd.block_id_to_num(hah.block_id) AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
WHERE hah.block_id IN (
    -- Canonical block_ids: highest block_id per block_num
    SELECT DISTINCT ON (hafd.block_id_to_num(block_id)) block_id
    FROM hafd.blocks
    ORDER BY hafd.block_id_to_num(block_id), block_id DESC
)
ORDER BY hah.hardfork_num, hah.block_id DESC;

-- =============================================================================
-- Irreversible views - Only show data from irreversible blocks
-- A row is irreversible if:
--   1. block_num <= block_id_to_num(consistent_block)
--   2. For that block_num, it has the MAX(fork_id) where fork_id <= block_id_to_fork(consistent_block)
-- Each table needs its own windowing since rows have their own block_ids.
-- =============================================================================

-- Uses DISTINCT ON for canonical selection within irreversible range.
CREATE OR REPLACE VIEW hive.irreversible_blocks_view AS
SELECT DISTINCT ON (hafd.block_id_to_num(hb.block_id))
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
ORDER BY hafd.block_id_to_num(hb.block_id), hb.block_id DESC;

-- Uses DISTINCT ON for canonical selection within irreversible range.
CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS
SELECT DISTINCT ON (hafd.block_id_to_num(ht.block_id), ht.trx_in_block)
    hafd.block_id_to_num(ht.block_id) AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(ht.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hafd.block_id_to_fork(ht.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
ORDER BY hafd.block_id_to_num(ht.block_id), ht.trx_in_block, ht.block_id DESC;

-- Uses DISTINCT ON for canonical selection within irreversible range.
CREATE OR REPLACE VIEW hive.irreversible_operations_view AS
SELECT DISTINCT ON ((ho.id >> 8))
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
ORDER BY (ho.id >> 8), ho.block_id DESC;

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
