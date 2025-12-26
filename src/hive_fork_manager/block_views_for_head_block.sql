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
--
-- Performance note: We use inline bit operations instead of function calls:
--   - (block_id >> 32)::int extracts block_num (upper 32 bits)
--   - (block_id & x'FFFFFFFF'::bigint)::int extracts fork_id (lower 32 bits)
-- This avoids C function call overhead and allows better query optimization.
-- =============================================================================

-- =============================================================================
-- blocks_view - Uses block_id from blocks table
-- =============================================================================
-- Uses DISTINCT ON for efficient predicate pushdown when filtering by block_num.
-- For each block_num, picks the block with highest block_id (latest fork version).
CREATE OR REPLACE VIEW hive.blocks_view AS
SELECT DISTINCT ON ((hb.block_id >> 32)::int)
    (hb.block_id >> 32)::int AS num,
    hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
    hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
    hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
    hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
    hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
FROM hafd.blocks hb
ORDER BY (hb.block_id >> 32)::int, hb.block_id DESC;

-- =============================================================================
-- transactions_view - For each (block_num, trx_in_block), show highest fork_id version
-- =============================================================================
-- Uses DISTINCT ON for efficient predicate pushdown when filtering by block_num.
CREATE OR REPLACE VIEW hive.transactions_view AS
SELECT DISTINCT ON ((ht.block_id >> 32)::int, ht.trx_in_block)
    (ht.block_id >> 32)::int AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
ORDER BY (ht.block_id >> 32)::int, ht.trx_in_block, ht.block_id DESC;

-- =============================================================================
-- operations_view - For each (block_num, seq_in_block), show highest fork_id version
-- =============================================================================
-- Uses DISTINCT ON for efficient predicate pushdown when filtering by block_num.
CREATE OR REPLACE VIEW hive.operations_view AS
SELECT DISTINCT ON ((ho.block_id >> 32)::int, ho.seq_in_block)
    ho.id,
    (ho.block_id >> 32)::int AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    ho.op_type_id,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
ORDER BY (ho.block_id >> 32)::int, ho.seq_in_block, ho.block_id DESC;

-- =============================================================================
-- operations_view_extended - For each (block_num, seq_in_block), show highest fork_id version with timestamp
-- =============================================================================
-- Uses DISTINCT ON for efficient predicate pushdown when filtering by block_num.
CREATE OR REPLACE VIEW hive.operations_view_extended AS
SELECT DISTINCT ON ((ho.block_id >> 32)::int, ho.seq_in_block)
    ho.id,
    (ho.block_id >> 32)::int AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    ho.op_type_id,
    b.created_at AS timestamp,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
JOIN hafd.blocks b ON b.block_id = ho.block_id
ORDER BY (ho.block_id >> 32)::int, ho.seq_in_block, ho.block_id DESC;

-- =============================================================================
-- account_operations_view - Show account_ops from visible blocks,
-- then for each (account_id, account_op_seq_no), pick highest block_id
-- =============================================================================
-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.account_operations_view AS
SELECT DISTINCT ON (hao.account_id, hao.account_op_seq_no)
    (hao.block_id >> 32)::int AS block_num,
    hao.account_id,
    hao.transacting_account_id,
    hao.account_op_seq_no,
    ho.id AS operation_id,
    ho.op_type_id
FROM hafd.account_operations hao
JOIN hafd.operations ho ON ho.block_id = hao.block_id AND ho.seq_in_block = hao.seq_in_block
JOIN (
    SELECT DISTINCT ON ((block_id >> 32)::int) block_id
    FROM hafd.blocks
    ORDER BY (block_id >> 32)::int, block_id DESC
) visible ON visible.block_id = hao.block_id
ORDER BY hao.account_id, hao.account_op_seq_no, hao.block_id DESC;

-- =============================================================================
-- accounts_view - Show accounts from visible (canonical) blocks only
-- For each account_id, pick the row with highest block_id from visible blocks
-- NULL block_id means account was dumped at startup (psql-first-block > 1)
-- =============================================================================
-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT DISTINCT ON (ha.id)
    ha.id, ha.name
FROM hafd.accounts ha
WHERE ha.block_id IS NULL  -- Accounts from initial dump
   OR ha.block_id IN (
       SELECT DISTINCT ON ((block_id >> 32)::int) block_id
       FROM hafd.blocks
       ORDER BY (block_id >> 32)::int, block_id DESC
   )
ORDER BY ha.id, ha.block_id DESC NULLS LAST;

-- =============================================================================
-- transactions_multisig_view - Show signatures from visible blocks only
-- =============================================================================
-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
JOIN (
    SELECT DISTINCT ON ((block_id >> 32)::int) block_id
    FROM hafd.blocks
    ORDER BY (block_id >> 32)::int, block_id DESC
) visible ON visible.block_id = htm.block_id;

-- =============================================================================
-- applied_hardforks_view - Show hardforks from visible blocks,
-- then for each hardfork_num, pick the highest block_id
-- =============================================================================
-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
SELECT DISTINCT ON (hah.hardfork_num)
    hah.hardfork_num,
    (hah.block_id >> 32)::int AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
JOIN (
    SELECT DISTINCT ON ((block_id >> 32)::int) block_id
    FROM hafd.blocks
    ORDER BY (block_id >> 32)::int, block_id DESC
) visible ON visible.block_id = hah.block_id
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
SELECT DISTINCT ON ((hb.block_id >> 32)::int)
    (hb.block_id >> 32)::int AS num,
    hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
    hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
    hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
    hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
    hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
FROM hafd.blocks hb
CROSS JOIN hafd.hive_state hs
WHERE (hb.block_id >> 32)::int <= (hs.consistent_block >> 32)::int
  AND (hb.block_id & x'FFFFFFFF'::bigint)::int <= (hs.consistent_block & x'FFFFFFFF'::bigint)::int
ORDER BY (hb.block_id >> 32)::int, (hb.block_id & x'FFFFFFFF'::bigint)::int DESC;

-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS
SELECT DISTINCT ON ((ht.block_id >> 32)::int, ht.trx_in_block)
    (ht.block_id >> 32)::int AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
CROSS JOIN hafd.hive_state hs
WHERE (ht.block_id >> 32)::int <= (hs.consistent_block >> 32)::int
  AND (ht.block_id & x'FFFFFFFF'::bigint)::int <= (hs.consistent_block & x'FFFFFFFF'::bigint)::int
ORDER BY (ht.block_id >> 32)::int, ht.trx_in_block, (ht.block_id & x'FFFFFFFF'::bigint)::int DESC;

-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.irreversible_operations_view AS
SELECT DISTINCT ON ((ho.block_id >> 32)::int, ho.seq_in_block)
    ho.id,
    (ho.block_id >> 32)::int AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    ho.op_type_id,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
CROSS JOIN hafd.hive_state hs
WHERE (ho.block_id >> 32)::int <= (hs.consistent_block >> 32)::int
  AND (ho.block_id & x'FFFFFFFF'::bigint)::int <= (hs.consistent_block & x'FFFFFFFF'::bigint)::int
ORDER BY (ho.block_id >> 32)::int, ho.seq_in_block, (ho.block_id & x'FFFFFFFF'::bigint)::int DESC;

-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.irreversible_operations_view_extended AS
SELECT DISTINCT ON ((ho.block_id >> 32)::int, ho.seq_in_block)
    ho.id,
    (ho.block_id >> 32)::int AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    ho.op_type_id,
    b.created_at AS timestamp,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
JOIN hafd.blocks b ON b.block_id = ho.block_id
CROSS JOIN hafd.hive_state hs
WHERE (ho.block_id >> 32)::int <= (hs.consistent_block >> 32)::int
  AND (ho.block_id & x'FFFFFFFF'::bigint)::int <= (hs.consistent_block & x'FFFFFFFF'::bigint)::int
ORDER BY (ho.block_id >> 32)::int, ho.seq_in_block, (ho.block_id & x'FFFFFFFF'::bigint)::int DESC;

-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.irreversible_account_operations_view AS
SELECT DISTINCT ON (hao.account_id, hao.account_op_seq_no)
    (hao.block_id >> 32)::int AS block_num,
    hao.account_id,
    hao.transacting_account_id,
    hao.account_op_seq_no,
    ho.id AS operation_id,
    ho.op_type_id
FROM hafd.account_operations hao
JOIN hafd.operations ho ON ho.block_id = hao.block_id AND ho.seq_in_block = hao.seq_in_block
CROSS JOIN hafd.hive_state hs
WHERE (hao.block_id >> 32)::int <= (hs.consistent_block >> 32)::int
  AND (hao.block_id & x'FFFFFFFF'::bigint)::int <= (hs.consistent_block & x'FFFFFFFF'::bigint)::int
ORDER BY hao.account_id, hao.account_op_seq_no, (hao.block_id & x'FFFFFFFF'::bigint)::int DESC;

-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS
SELECT DISTINCT ON (ha.id)
    ha.id, ha.name
FROM hafd.accounts ha
CROSS JOIN hafd.hive_state hs
WHERE ha.block_id IS NULL  -- Accounts from initial dump (psql-first-block > 1)
   OR ((ha.block_id >> 32)::int <= (hs.consistent_block >> 32)::int
       AND (ha.block_id & x'FFFFFFFF'::bigint)::int <= (hs.consistent_block & x'FFFFFFFF'::bigint)::int)
ORDER BY ha.id, ha.block_id DESC NULLS LAST;

-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS
SELECT DISTINCT ON (htm.trx_hash, htm.signature)
    htm.trx_hash,
    htm.signature
FROM hafd.transactions_multisig htm
CROSS JOIN hafd.hive_state hs
WHERE (htm.block_id >> 32)::int <= (hs.consistent_block >> 32)::int
  AND (htm.block_id & x'FFFFFFFF'::bigint)::int <= (hs.consistent_block & x'FFFFFFFF'::bigint)::int
ORDER BY htm.trx_hash, htm.signature, (htm.block_id & x'FFFFFFFF'::bigint)::int DESC;

-- Uses DISTINCT ON for efficient predicate pushdown.
CREATE OR REPLACE VIEW hive.irreversible_applied_hardforks_view AS
SELECT DISTINCT ON (hah.hardfork_num)
    hah.hardfork_num,
    (hah.block_id >> 32)::int AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
CROSS JOIN hafd.hive_state hs
WHERE (hah.block_id >> 32)::int <= (hs.consistent_block >> 32)::int
  AND (hah.block_id & x'FFFFFFFF'::bigint)::int <= (hs.consistent_block & x'FFFFFFFF'::bigint)::int
ORDER BY hah.hardfork_num, (hah.block_id & x'FFFFFFFF'::bigint)::int DESC;
