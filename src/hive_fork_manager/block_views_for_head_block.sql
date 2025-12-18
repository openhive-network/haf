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
CREATE OR REPLACE VIEW hive.blocks_view AS
SELECT num, hash, prev, created_at, producer_account_id,
       transaction_merkle_root, extensions, witness_signature,
       signing_key, hbd_interest_rate, total_vesting_fund_hive,
       total_vesting_shares, total_reward_fund_hive, virtual_supply,
       current_supply, current_hbd_supply, dhf_interval_ledger
FROM (
    SELECT
        hafd.block_id_to_num(hb.block_id) AS num,
        hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
        hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
        hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
        hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
        hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger,
        ROW_NUMBER() OVER (
            PARTITION BY hafd.block_id_to_num(hb.block_id)
            ORDER BY hb.block_id DESC
        ) AS rn
    FROM hafd.blocks hb
) t WHERE rn = 1;

-- =============================================================================
-- transactions_view - For each (block_num, trx_in_block), show highest fork_id version
-- =============================================================================
CREATE OR REPLACE VIEW hive.transactions_view AS
SELECT block_num, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature
FROM (
    SELECT
        hafd.block_id_to_num(ht.block_id) AS block_num,
        ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
        ht.ref_block_prefix, ht.expiration, ht.signature,
        ROW_NUMBER() OVER (
            PARTITION BY hafd.block_id_to_num(ht.block_id), ht.trx_in_block
            ORDER BY ht.block_id DESC
        ) AS rn
    FROM hafd.transactions ht
) t WHERE rn = 1;

-- =============================================================================
-- operations_view - For each (block_num, seq_in_block), show highest fork_id version
-- =============================================================================
CREATE OR REPLACE VIEW hive.operations_view AS
SELECT id, block_num, trx_in_block, op_pos, op_type_id, body_binary, body
FROM (
    SELECT
        ho.id,
        hafd.block_id_to_num(ho.block_id) AS block_num,
        ho.trx_in_block,
        ho.op_pos,
        ho.op_type_id,
        ho.body_binary,
        ho.body_binary::jsonb AS body,
        ROW_NUMBER() OVER (
            PARTITION BY hafd.block_id_to_num(ho.block_id), ho.seq_in_block
            ORDER BY ho.block_id DESC
        ) AS rn
    FROM hafd.operations ho
) t WHERE rn = 1;

-- =============================================================================
-- operations_view_extended - For each (block_num, seq_in_block), show highest fork_id version with timestamp
-- =============================================================================
CREATE OR REPLACE VIEW hive.operations_view_extended AS
SELECT id, block_num, trx_in_block, op_pos, op_type_id, timestamp, body_binary, body
FROM (
    SELECT
        ho.id,
        hafd.block_id_to_num(ho.block_id) AS block_num,
        ho.trx_in_block,
        ho.op_pos,
        ho.op_type_id,
        b.created_at AS timestamp,
        ho.body_binary,
        ho.body_binary::jsonb AS body,
        ROW_NUMBER() OVER (
            PARTITION BY hafd.block_id_to_num(ho.block_id), ho.seq_in_block
            ORDER BY ho.block_id DESC
        ) AS rn
    FROM hafd.operations ho
    JOIN hafd.blocks b ON b.block_id = ho.block_id
) t WHERE rn = 1;

-- =============================================================================
-- account_operations_view - Show account_ops from visible blocks,
-- then for each (account_id, account_op_seq_no), pick highest block_id
-- =============================================================================
CREATE OR REPLACE VIEW hive.account_operations_view AS
SELECT block_num, account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id
FROM (
    SELECT
        hafd.block_id_to_num(hao.block_id) AS block_num,
        hao.account_id,
        hao.transacting_account_id,
        hao.account_op_seq_no,
        ho.id AS operation_id,
        ho.op_type_id,
        ROW_NUMBER() OVER (
            PARTITION BY hao.account_id, hao.account_op_seq_no
            ORDER BY hao.block_id DESC
        ) AS rn
    FROM hafd.account_operations hao
    JOIN hafd.operations ho ON ho.block_id = hao.block_id AND ho.seq_in_block = hao.seq_in_block
    JOIN (
        SELECT block_id
        FROM (
            SELECT block_id,
                ROW_NUMBER() OVER (
                    PARTITION BY hafd.block_id_to_num(block_id)
                    ORDER BY block_id DESC
                ) AS rn
            FROM hafd.blocks
        ) t WHERE rn = 1
    ) visible ON visible.block_id = hao.block_id
) t WHERE rn = 1;

-- =============================================================================
-- accounts_view - Show accounts from visible blocks only
-- For each block_num, the visible block is the one with highest fork_id
-- =============================================================================
CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT ha.id, ha.name
FROM hafd.accounts ha
JOIN (
    SELECT block_id
    FROM (
        SELECT block_id,
            ROW_NUMBER() OVER (
                PARTITION BY hafd.block_id_to_num(block_id)
                ORDER BY block_id DESC
            ) AS rn
        FROM hafd.blocks
    ) t WHERE rn = 1
) visible ON visible.block_id = ha.block_id;

-- =============================================================================
-- transactions_multisig_view - Show signatures from visible blocks only
-- =============================================================================
CREATE OR REPLACE VIEW hive.transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
JOIN (
    SELECT block_id
    FROM (
        SELECT block_id,
            ROW_NUMBER() OVER (
                PARTITION BY hafd.block_id_to_num(block_id)
                ORDER BY block_id DESC
            ) AS rn
        FROM hafd.blocks
    ) t WHERE rn = 1
) visible ON visible.block_id = htm.block_id;

-- =============================================================================
-- applied_hardforks_view - Show hardforks from visible blocks,
-- then for each hardfork_num, pick the highest block_id
-- =============================================================================
CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
SELECT hardfork_num, block_num, hardfork_vop_id
FROM (
    SELECT
        hah.hardfork_num,
        hafd.block_id_to_num(hah.block_id) AS block_num,
        hah.hardfork_vop_id,
        ROW_NUMBER() OVER (
            PARTITION BY hah.hardfork_num
            ORDER BY hah.block_id DESC
        ) AS rn
    FROM hafd.applied_hardforks hah
    JOIN (
        SELECT block_id
        FROM (
            SELECT block_id,
                ROW_NUMBER() OVER (
                    PARTITION BY hafd.block_id_to_num(block_id)
                    ORDER BY block_id DESC
                ) AS rn
            FROM hafd.blocks
        ) t WHERE rn = 1
    ) visible ON visible.block_id = hah.block_id
) t WHERE rn = 1;

-- =============================================================================
-- Irreversible views - Only show data from irreversible blocks
-- A row is irreversible if:
--   1. block_num <= block_id_to_num(consistent_block)
--   2. For that block_num, it has the MAX(fork_id) where fork_id <= block_id_to_fork(consistent_block)
-- Each table needs its own windowing since rows have their own block_ids.
-- =============================================================================

CREATE OR REPLACE VIEW hive.irreversible_blocks_view AS
SELECT num, hash, prev, created_at, producer_account_id,
       transaction_merkle_root, extensions, witness_signature,
       signing_key, hbd_interest_rate, total_vesting_fund_hive,
       total_vesting_shares, total_reward_fund_hive, virtual_supply,
       current_supply, current_hbd_supply, dhf_interval_ledger
FROM (
    SELECT
        hafd.block_id_to_num(hb.block_id) AS num,
        hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
        hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
        hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
        hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
        hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger,
        ROW_NUMBER() OVER (
            PARTITION BY hafd.block_id_to_num(hb.block_id)
            ORDER BY hafd.block_id_to_fork(hb.block_id) DESC
        ) AS rn
    FROM hafd.blocks hb
    CROSS JOIN hafd.hive_state hs
    WHERE hafd.block_id_to_num(hb.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      AND hafd.block_id_to_fork(hb.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
) t WHERE rn = 1;

CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS
SELECT block_num, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature
FROM (
    SELECT
        hafd.block_id_to_num(ht.block_id) AS block_num,
        ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
        ht.ref_block_prefix, ht.expiration, ht.signature,
        ROW_NUMBER() OVER (
            PARTITION BY hafd.block_id_to_num(ht.block_id), ht.trx_in_block
            ORDER BY hafd.block_id_to_fork(ht.block_id) DESC
        ) AS rn
    FROM hafd.transactions ht
    CROSS JOIN hafd.hive_state hs
    WHERE hafd.block_id_to_num(ht.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      AND hafd.block_id_to_fork(ht.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
) t WHERE rn = 1;

CREATE OR REPLACE VIEW hive.irreversible_operations_view AS
SELECT id, block_num, trx_in_block, op_pos, op_type_id, body_binary, body
FROM (
    SELECT
        ho.id,
        hafd.block_id_to_num(ho.block_id) AS block_num,
        ho.trx_in_block,
        ho.op_pos,
        ho.op_type_id,
        ho.body_binary,
        ho.body_binary::jsonb AS body,
        ROW_NUMBER() OVER (
            PARTITION BY hafd.block_id_to_num(ho.block_id), ho.seq_in_block
            ORDER BY hafd.block_id_to_fork(ho.block_id) DESC
        ) AS rn
    FROM hafd.operations ho
    CROSS JOIN hafd.hive_state hs
    WHERE hafd.block_id_to_num(ho.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      AND hafd.block_id_to_fork(ho.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
) t WHERE rn = 1;

CREATE OR REPLACE VIEW hive.irreversible_operations_view_extended AS
SELECT id, block_num, trx_in_block, op_pos, op_type_id, timestamp, body_binary, body
FROM (
    SELECT
        ho.id,
        hafd.block_id_to_num(ho.block_id) AS block_num,
        ho.trx_in_block,
        ho.op_pos,
        ho.op_type_id,
        b.created_at AS timestamp,
        ho.body_binary,
        ho.body_binary::jsonb AS body,
        ROW_NUMBER() OVER (
            PARTITION BY hafd.block_id_to_num(ho.block_id), ho.seq_in_block
            ORDER BY hafd.block_id_to_fork(ho.block_id) DESC
        ) AS rn
    FROM hafd.operations ho
    JOIN hafd.blocks b ON b.block_id = ho.block_id
    CROSS JOIN hafd.hive_state hs
    WHERE hafd.block_id_to_num(ho.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      AND hafd.block_id_to_fork(ho.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
) t WHERE rn = 1;

CREATE OR REPLACE VIEW hive.irreversible_account_operations_view AS
SELECT block_num, account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id
FROM (
    SELECT
        hafd.block_id_to_num(hao.block_id) AS block_num,
        hao.account_id,
        hao.transacting_account_id,
        hao.account_op_seq_no,
        ho.id AS operation_id,
        ho.op_type_id,
        ROW_NUMBER() OVER (
            PARTITION BY hao.account_id, hao.account_op_seq_no
            ORDER BY hafd.block_id_to_fork(hao.block_id) DESC
        ) AS rn
    FROM hafd.account_operations hao
    JOIN hafd.operations ho ON ho.block_id = hao.block_id AND ho.seq_in_block = hao.seq_in_block
    CROSS JOIN hafd.hive_state hs
    WHERE hafd.block_id_to_num(hao.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      AND hafd.block_id_to_fork(hao.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
) t WHERE rn = 1;

CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS
SELECT id, name
FROM (
    SELECT
        ha.id,
        ha.name,
        ROW_NUMBER() OVER (
            PARTITION BY ha.id
            ORDER BY hafd.block_id_to_fork(ha.block_id) DESC
        ) AS rn
    FROM hafd.accounts ha
    CROSS JOIN hafd.hive_state hs
    WHERE hafd.block_id_to_num(ha.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      AND hafd.block_id_to_fork(ha.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
) t WHERE rn = 1;

CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS
SELECT trx_hash, signature
FROM (
    SELECT
        htm.trx_hash,
        htm.signature,
        ROW_NUMBER() OVER (
            PARTITION BY htm.trx_hash, htm.signature
            ORDER BY hafd.block_id_to_fork(htm.block_id) DESC
        ) AS rn
    FROM hafd.transactions_multisig htm
    CROSS JOIN hafd.hive_state hs
    WHERE hafd.block_id_to_num(htm.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      AND hafd.block_id_to_fork(htm.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
) t WHERE rn = 1;

CREATE OR REPLACE VIEW hive.irreversible_applied_hardforks_view AS
SELECT hardfork_num, block_num, hardfork_vop_id
FROM (
    SELECT
        hah.hardfork_num,
        hafd.block_id_to_num(hah.block_id) AS block_num,
        hah.hardfork_vop_id,
        ROW_NUMBER() OVER (
            PARTITION BY hah.hardfork_num
            ORDER BY hafd.block_id_to_fork(hah.block_id) DESC
        ) AS rn
    FROM hafd.applied_hardforks hah
    CROSS JOIN hafd.hive_state hs
    WHERE hafd.block_id_to_num(hah.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      AND hafd.block_id_to_fork(hah.block_id) <= hafd.block_id_to_fork(hs.consistent_block)
) t WHERE rn = 1;
