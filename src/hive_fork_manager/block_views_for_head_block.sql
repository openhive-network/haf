-- =============================================================================
-- Head Block Views for hive schema
-- =============================================================================
-- These views show all data including reversible blocks.
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
-- Uses DISTINCT ON for efficient predicate pushdown when filtering by block_num.
-- For each block_num, picks the block with highest block_id (latest fork version).
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
-- Uses DISTINCT ON for efficient predicate pushdown when filtering by block_num.
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
-- Uses DISTINCT ON with operation_id functions to match expression index,
-- enabling predicate pushdown when filtering by block_num.
-- operation_id_to_pos extracts the unique sequence number within a block.
CREATE OR REPLACE VIEW hive.operations_view AS
SELECT DISTINCT ON (hafd.operation_id_to_block_num(ho.id), hafd.operation_id_to_pos(ho.id))
    ho.id,
    hafd.operation_id_to_block_num(ho.id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    hafd.operation_id_to_type_id(ho.id) AS op_type_id,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
ORDER BY hafd.operation_id_to_block_num(ho.id), hafd.operation_id_to_pos(ho.id), ho.block_id DESC;

-- =============================================================================
-- operations_view_extended - For each (block_num, seq_in_block), show highest fork_id version with timestamp
-- =============================================================================
-- Uses DISTINCT ON with operation_id functions to match expression index,
-- enabling predicate pushdown when filtering by block_num.
CREATE OR REPLACE VIEW hive.operations_view_extended AS
SELECT DISTINCT ON (hafd.operation_id_to_block_num(ho.id), hafd.operation_id_to_pos(ho.id))
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
ORDER BY hafd.operation_id_to_block_num(ho.id), hafd.operation_id_to_pos(ho.id), ho.block_id DESC;

-- =============================================================================
-- account_operations_view - Show account_ops from visible blocks,
-- then for each (account_id, account_op_seq_no), pick highest block_id
-- =============================================================================
-- Uses MAX subquery for efficient canonical block check.
-- A block is canonical if it's the MAX(block_id) for its block_num.
-- MAX returns NULL if block doesn't exist, correctly filtering orphaned rows.
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
WHERE hao.block_id = (
    SELECT MAX(b.block_id) FROM hafd.blocks b
    WHERE hafd.block_id_to_num(b.block_id) = hafd.block_id_to_num(hao.block_id)
)
ORDER BY hao.account_id, hao.account_op_seq_no, hao.block_id DESC;

-- =============================================================================
-- accounts_view - Show accounts from visible (canonical) blocks only
-- For each account_id, pick the row with highest block_id from visible blocks
-- NULL block_id means account was dumped at startup (psql-first-block > 1)
-- =============================================================================
-- Uses MAX subquery for efficient canonical block check.
-- A block is canonical if it's the MAX(block_id) for its block_num.
-- MAX returns NULL if block doesn't exist, correctly filtering orphaned rows.
CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT DISTINCT ON (ha.id)
    ha.id, ha.name
FROM hafd.accounts ha
WHERE ha.block_id IS NULL  -- Accounts from initial dump
   OR ha.block_id = (
       SELECT MAX(b.block_id) FROM hafd.blocks b
       WHERE hafd.block_id_to_num(b.block_id) = hafd.block_id_to_num(ha.block_id)
   )
ORDER BY ha.id, ha.block_id DESC NULLS LAST;

-- =============================================================================
-- transactions_multisig_view - Show signatures from visible blocks only
-- =============================================================================
-- Uses MAX subquery for efficient canonical block check.
CREATE OR REPLACE VIEW hive.transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
WHERE htm.block_id = (
    SELECT MAX(b.block_id) FROM hafd.blocks b
    WHERE hafd.block_id_to_num(b.block_id) = hafd.block_id_to_num(htm.block_id)
);

-- =============================================================================
-- applied_hardforks_view - Show hardforks from visible blocks,
-- then for each hardfork_num, pick the highest block_id
-- =============================================================================
-- Uses MAX subquery for efficient canonical block check.
CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
SELECT DISTINCT ON (hah.hardfork_num)
    hah.hardfork_num,
    hafd.block_id_to_num(hah.block_id) AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
WHERE hah.block_id = (
    SELECT MAX(b.block_id) FROM hafd.blocks b
    WHERE hafd.block_id_to_num(b.block_id) = hafd.block_id_to_num(hah.block_id)
)
ORDER BY hah.hardfork_num, hah.block_id DESC;

-- =============================================================================
-- Irreversible views - Only show data from irreversible blocks
-- A row is irreversible if:
--   1. block_num <= block_id_to_num(consistent_block)
--   2. For that block_num, it has the MAX(fork_id) where fork_id <= block_id_to_fork(consistent_block)
-- Each table needs its own windowing since rows have their own block_ids.
-- =============================================================================

-- Uses DISTINCT ON for efficient predicate pushdown.
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
ORDER BY hafd.block_id_to_num(hb.block_id), hafd.block_id_to_fork(hb.block_id) DESC;

-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS
SELECT DISTINCT ON (hafd.block_id_to_num(ht.block_id), ht.trx_in_block)
    hafd.block_id_to_num(ht.block_id) AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(ht.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hafd.block_id_to_fork(ht.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
ORDER BY hafd.block_id_to_num(ht.block_id), ht.trx_in_block, hafd.block_id_to_fork(ht.block_id) DESC;

-- Uses DISTINCT ON with operation_id functions to match expression index.
CREATE OR REPLACE VIEW hive.irreversible_operations_view AS
SELECT DISTINCT ON (hafd.operation_id_to_block_num(ho.id), hafd.operation_id_to_pos(ho.id))
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
ORDER BY hafd.operation_id_to_block_num(ho.id), hafd.operation_id_to_pos(ho.id), ho.block_id DESC;

-- Uses DISTINCT ON with operation_id functions to match expression index.
CREATE OR REPLACE VIEW hive.irreversible_operations_view_extended AS
SELECT DISTINCT ON (hafd.operation_id_to_block_num(ho.id), hafd.operation_id_to_pos(ho.id))
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
ORDER BY hafd.operation_id_to_block_num(ho.id), hafd.operation_id_to_pos(ho.id), ho.block_id DESC;

-- Uses DISTINCT ON for efficient predicate pushdown.
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
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(hao.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hafd.block_id_to_fork(hao.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
ORDER BY hao.account_id, hao.account_op_seq_no, hafd.block_id_to_fork(hao.block_id) DESC;

-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS
SELECT DISTINCT ON (ha.id)
    ha.id, ha.name
FROM hafd.accounts ha
CROSS JOIN hafd.hive_state hs
WHERE ha.block_id IS NULL  -- Accounts from initial dump (psql-first-block > 1)
   OR (hafd.block_id_to_num(ha.block_id) <= hafd.block_id_to_num(hs.consistent_block)
       AND hafd.block_id_to_fork(ha.block_id) <= hafd.block_id_to_fork(hs.consistent_block))
ORDER BY ha.id, ha.block_id DESC NULLS LAST;

-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS
SELECT DISTINCT ON (htm.trx_hash, htm.signature)
    htm.trx_hash,
    htm.signature
FROM hafd.transactions_multisig htm
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(htm.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hafd.block_id_to_fork(htm.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
ORDER BY htm.trx_hash, htm.signature, hafd.block_id_to_fork(htm.block_id) DESC;

-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.irreversible_applied_hardforks_view AS
SELECT DISTINCT ON (hah.hardfork_num)
    hah.hardfork_num,
    hafd.block_id_to_num(hah.block_id) AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(hah.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hafd.block_id_to_fork(hah.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
ORDER BY hah.hardfork_num, hafd.block_id_to_fork(hah.block_id) DESC;
