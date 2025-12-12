-- =============================================================================
-- Head Block Views for hive schema
-- =============================================================================
-- These views show data up to the current head block, selecting canonical rows
-- from the canonical chain (highest block_id = most recent fork per block_num).
-- =============================================================================

-- =============================================================================
-- account_operations_view
-- =============================================================================
CREATE OR REPLACE VIEW hive.account_operations_view AS
SELECT block_num, account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id
FROM (
    SELECT
        hafd.block_id_to_num(hao.block_id) AS block_num,
        hao.account_id,
        hao.transacting_account_id,
        hao.account_op_seq_no,
        hafd.operation_id(hao.block_id, hao.seq_in_block, ho.op_type_id) AS operation_id,
        ho.op_type_id,
        ROW_NUMBER() OVER (
            PARTITION BY hao.account_id, hao.account_op_seq_no
            ORDER BY hafd.block_id_to_num(hao.block_id) DESC, hao.block_id DESC
        ) AS rn
    FROM hafd.account_operations hao
    JOIN hafd.operations ho ON ho.block_id = hao.block_id AND ho.seq_in_block = hao.seq_in_block
    -- Only include rows from canonical blocks
    WHERE EXISTS (
        SELECT 1 FROM (
            SELECT block_id FROM hafd.blocks hb
            WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(hao.block_id)
            ORDER BY hb.block_id DESC LIMIT 1
        ) canonical WHERE canonical.block_id = hao.block_id
    )
) t WHERE rn = 1;

-- =============================================================================
-- accounts_view
-- =============================================================================
CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT id, name
FROM (
    SELECT
        ha.id,
        ha.name,
        ROW_NUMBER() OVER (
            PARTITION BY ha.id
            ORDER BY hafd.block_id_to_num(ha.block_id) DESC, ha.block_id DESC
        ) AS rn
    FROM hafd.accounts ha
    -- Only include accounts from canonical blocks
    WHERE EXISTS (
        SELECT 1 FROM (
            SELECT block_id FROM hafd.blocks hb
            WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(ha.block_id)
            ORDER BY hb.block_id DESC LIMIT 1
        ) canonical WHERE canonical.block_id = ha.block_id
    )
) t WHERE rn = 1;

-- =============================================================================
-- blocks_view (no change needed - partitions by block_num)
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
-- transactions_view (partitions by block_num, trx_in_block - OK)
-- =============================================================================
CREATE OR REPLACE VIEW hive.transactions_view AS
SELECT block_num, trx_in_block, trx_hash, ref_block_num,
       ref_block_prefix, expiration, signature
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
-- operations_view_extended (partitions by block_num, seq_in_block - OK)
-- =============================================================================
CREATE OR REPLACE VIEW hive.operations_view_extended AS
SELECT id, block_num, trx_in_block, op_pos, op_type_id, timestamp, body_binary, body
FROM (
    SELECT
        hafd.operation_id(ho.block_id, ho.seq_in_block, ho.op_type_id) AS id,
        hafd.block_id_to_num(ho.block_id) AS block_num,
        ho.trx_in_block, ho.op_pos, ho.op_type_id,
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
-- operations_view (partitions by block_num, seq_in_block - OK)
-- =============================================================================
CREATE OR REPLACE VIEW hive.operations_view AS
SELECT id, block_num, trx_in_block, op_pos, op_type_id, body_binary, body
FROM (
    SELECT
        hafd.operation_id(ho.block_id, ho.seq_in_block, ho.op_type_id) AS id,
        hafd.block_id_to_num(ho.block_id) AS block_num,
        ho.trx_in_block, ho.op_pos, ho.op_type_id,
        ho.body_binary,
        ho.body_binary::jsonb AS body,
        ROW_NUMBER() OVER (
            PARTITION BY hafd.block_id_to_num(ho.block_id), ho.seq_in_block
            ORDER BY ho.block_id DESC
        ) AS rn
    FROM hafd.operations ho
) t WHERE rn = 1;

-- =============================================================================
-- transactions_multisig_view (partitions by trx_hash, signature - needs canonical filter)
-- =============================================================================
CREATE OR REPLACE VIEW hive.transactions_multisig_view AS
SELECT trx_hash, signature
FROM (
    SELECT
        ht.trx_hash,
        htm.signature,
        ROW_NUMBER() OVER (
            PARTITION BY ht.trx_hash, htm.signature
            ORDER BY htm.block_id DESC
        ) AS rn
    FROM hafd.transactions_multisig htm
    JOIN hafd.transactions ht ON ht.block_id = htm.block_id AND ht.trx_in_block = htm.trx_in_block
    -- Only include rows from canonical blocks
    WHERE EXISTS (
        SELECT 1 FROM (
            SELECT block_id FROM hafd.blocks hb
            WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(htm.block_id)
            ORDER BY hb.block_id DESC LIMIT 1
        ) canonical WHERE canonical.block_id = htm.block_id
    )
) t WHERE rn = 1;

-- =============================================================================
-- applied_hardforks_view (partitions by hardfork_num - needs canonical filter)
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
            ORDER BY hafd.block_id_to_num(hah.block_id) DESC, hah.block_id DESC
        ) AS rn
    FROM hafd.applied_hardforks hah
    -- Only include rows from canonical blocks
    WHERE EXISTS (
        SELECT 1 FROM (
            SELECT block_id FROM hafd.blocks hb
            WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(hah.block_id)
            ORDER BY hb.block_id DESC LIMIT 1
        ) canonical WHERE canonical.block_id = hah.block_id
    )
) t WHERE rn = 1;

-- =============================================================================
-- Irreversible views - Only show data from fork_id=0 (truly irreversible)
-- =============================================================================
CREATE OR REPLACE VIEW hive.irreversible_account_operations_view AS
SELECT block_num, account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id
FROM (
    SELECT
        hafd.block_id_to_num(hao.block_id) AS block_num,
        hao.account_id,
        hao.transacting_account_id,
        hao.account_op_seq_no,
        hafd.operation_id(hao.block_id, hao.seq_in_block, ho.op_type_id) AS operation_id,
        ho.op_type_id,
        ROW_NUMBER() OVER (
            PARTITION BY hao.account_id, hao.account_op_seq_no
            ORDER BY hafd.block_id_to_num(hao.block_id) DESC
        ) AS rn
    FROM hafd.account_operations hao
    JOIN hafd.operations ho ON ho.block_id = hao.block_id AND ho.seq_in_block = hao.seq_in_block
    WHERE hafd.block_id_to_fork(hao.block_id) = 0  -- Only irreversible data (fork_id=0)
) t WHERE rn = 1;

CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS
SELECT id, name
FROM (
    SELECT
        ha.id,
        ha.name,
        ROW_NUMBER() OVER (
            PARTITION BY ha.id
            ORDER BY hafd.block_id_to_num(ha.block_id) DESC
        ) AS rn
    FROM hafd.accounts ha
    WHERE hafd.block_id_to_fork(ha.block_id) = 0  -- Only irreversible data (fork_id=0)
) t WHERE rn = 1;

CREATE OR REPLACE VIEW hive.irreversible_blocks_view AS
SELECT hafd.block_id_to_num(hb.block_id) AS num, hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
       hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
       hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
       hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
       hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
FROM hafd.blocks hb
WHERE hafd.block_id_to_fork(hb.block_id) = 0;  -- Only irreversible blocks (fork_id=0)

CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS
SELECT block_num, trx_in_block, trx_hash, ref_block_num,
       ref_block_prefix, expiration, signature
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
    WHERE hafd.block_id_to_fork(ht.block_id) = 0  -- Only irreversible data
) t WHERE rn = 1;

CREATE OR REPLACE VIEW hive.irreversible_operations_view_extended AS
SELECT id, block_num, trx_in_block, op_pos, op_type_id, timestamp, body_binary, body
FROM (
    SELECT
        hafd.operation_id(ho.block_id, ho.seq_in_block, ho.op_type_id) AS id,
        hafd.block_id_to_num(ho.block_id) AS block_num,
        ho.trx_in_block, ho.op_pos, ho.op_type_id,
        b.created_at AS timestamp,
        ho.body_binary,
        ho.body_binary::jsonb AS body,
        ROW_NUMBER() OVER (
            PARTITION BY hafd.block_id_to_num(ho.block_id), ho.seq_in_block
            ORDER BY ho.block_id DESC
        ) AS rn
    FROM hafd.operations ho
    JOIN hafd.blocks b ON b.block_id = ho.block_id
    WHERE hafd.block_id_to_fork(ho.block_id) = 0  -- Only irreversible data
) t WHERE rn = 1;

CREATE OR REPLACE VIEW hive.irreversible_operations_view AS
SELECT id, block_num, trx_in_block, op_pos, op_type_id, body_binary, body
FROM (
    SELECT
        hafd.operation_id(ho.block_id, ho.seq_in_block, ho.op_type_id) AS id,
        hafd.block_id_to_num(ho.block_id) AS block_num,
        ho.trx_in_block, ho.op_pos, ho.op_type_id,
        ho.body_binary,
        ho.body_binary::jsonb AS body,
        ROW_NUMBER() OVER (
            PARTITION BY hafd.block_id_to_num(ho.block_id), ho.seq_in_block
            ORDER BY ho.block_id DESC
        ) AS rn
    FROM hafd.operations ho
    WHERE hafd.block_id_to_fork(ho.block_id) = 0  -- Only irreversible data
) t WHERE rn = 1;

CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS
SELECT trx_hash, signature
FROM (
    SELECT
        ht.trx_hash,
        htm.signature,
        ROW_NUMBER() OVER (
            PARTITION BY ht.trx_hash, htm.signature
            ORDER BY htm.block_id DESC
        ) AS rn
    FROM hafd.transactions_multisig htm
    JOIN hafd.transactions ht ON ht.block_id = htm.block_id AND ht.trx_in_block = htm.trx_in_block
    WHERE hafd.block_id_to_fork(htm.block_id) = 0  -- Only irreversible data
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
            ORDER BY hafd.block_id_to_num(hah.block_id) DESC
        ) AS rn
    FROM hafd.applied_hardforks hah
    WHERE hafd.block_id_to_fork(hah.block_id) = 0  -- Only irreversible data
) t WHERE rn = 1;
