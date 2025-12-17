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
-- transactions_view - Uses block_num from transactions table
-- =============================================================================
CREATE OR REPLACE VIEW hive.transactions_view AS
SELECT hafd.block_id_to_num(ht.block_id) AS block_num, ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
       ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht;

-- =============================================================================
-- operations_view - Uses id encoding (block_num|seq|type)
-- =============================================================================
CREATE OR REPLACE VIEW hive.operations_view AS
SELECT
    ho.id,
    hafd.block_id_to_num(ho.block_id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    ho.op_type_id,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho;

-- =============================================================================
-- operations_view_extended - Uses id encoding with timestamp from blocks
-- =============================================================================
CREATE OR REPLACE VIEW hive.operations_view_extended AS
SELECT
    ho.id,
    hafd.block_id_to_num(ho.block_id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    ho.op_type_id,
    b.created_at AS timestamp,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
JOIN hafd.blocks b ON b.block_id = ho.block_id;

-- =============================================================================
-- account_operations_view - Uses operation_id encoding
-- =============================================================================
CREATE OR REPLACE VIEW hive.account_operations_view AS
SELECT
    hafd.block_id_to_num(hao.block_id) AS block_num,
    hao.account_id,
    hao.transacting_account_id,
    hao.account_op_seq_no,
    ho.id AS operation_id,
    ho.op_type_id
FROM hafd.account_operations hao
JOIN hafd.operations ho ON ho.block_id = hao.block_id AND ho.seq_in_block = hao.seq_in_block;

-- =============================================================================
-- accounts_view - Uses block_num from accounts table
-- =============================================================================
CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT ha.id, ha.name
FROM hafd.accounts ha;

-- =============================================================================
-- transactions_multisig_view - Uses trx_hash reference
-- =============================================================================
CREATE OR REPLACE VIEW hive.transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm;

-- =============================================================================
-- applied_hardforks_view - Uses block_num from applied_hardforks table
-- =============================================================================
CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
SELECT hah.hardfork_num, hafd.block_id_to_num(hah.block_id) AS block_num, hah.hardfork_vop_id
FROM hafd.applied_hardforks hah;

-- =============================================================================
-- Irreversible views - Only show data from irreversible blocks
-- With the hybrid schema, irreversible data is in the base tables.
-- Fork cleanup removes orphan data, so these are just simple views.
-- =============================================================================

CREATE OR REPLACE VIEW hive.irreversible_blocks_view AS
SELECT
    hafd.block_id_to_num(hb.block_id) AS num,
    hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
    hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
    hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
    hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
    hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
FROM hafd.blocks hb
WHERE hafd.block_id_to_fork(hb.block_id) = 0;

CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS
SELECT hafd.block_id_to_num(ht.block_id) AS block_num, ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
       ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht;

CREATE OR REPLACE VIEW hive.irreversible_operations_view AS
SELECT
    ho.id,
    hafd.block_id_to_num(ho.block_id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    ho.op_type_id,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho;

CREATE OR REPLACE VIEW hive.irreversible_operations_view_extended AS
SELECT
    ho.id,
    hafd.block_id_to_num(ho.block_id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    ho.op_type_id,
    b.created_at AS timestamp,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
JOIN hafd.blocks b ON b.block_id = ho.block_id;

CREATE OR REPLACE VIEW hive.irreversible_account_operations_view AS
SELECT
    hafd.block_id_to_num(hao.block_id) AS block_num,
    hao.account_id,
    hao.transacting_account_id,
    hao.account_op_seq_no,
    ho.id AS operation_id,
    ho.op_type_id
FROM hafd.account_operations hao
JOIN hafd.operations ho ON ho.block_id = hao.block_id AND ho.seq_in_block = hao.seq_in_block;

CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS
SELECT ha.id, ha.name
FROM hafd.accounts ha;

CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm;

CREATE OR REPLACE VIEW hive.irreversible_applied_hardforks_view AS
SELECT hah.hardfork_num, hafd.block_id_to_num(hah.block_id) AS block_num, hah.hardfork_vop_id
FROM hafd.applied_hardforks hah;
