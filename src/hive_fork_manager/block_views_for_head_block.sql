CREATE OR REPLACE VIEW hive.account_operations_view AS
  SELECT ha.account_id,
         ha.transacting_account_id,
         ha.account_op_seq_no,
         ha.operation_id,
         ha.op_type_id,
         hafd.operation_id_to_block_num( ha.operation_id ) as block_num
  FROM hafd.account_operations ha;

CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT
    ha.id,
    ha.name
FROM hafd.accounts ha;

CREATE OR REPLACE VIEW hive.blocks_view
AS
SELECT hb.num,
       hb.hash,
       hb.prev,
       hb.created_at,
       hb.producer_account_id,
       hb.transaction_merkle_root,
       hb.extensions,
       hb.witness_signature,
       hb.signing_key,
       hb.hbd_interest_rate,
       hb.total_vesting_fund_hive,
       hb.total_vesting_shares,
       hb.total_reward_fund_hive,
       hb.virtual_supply,
       hb.current_supply,
       hb.current_hbd_supply,
       hb.dhf_interval_ledger
FROM hafd.blocks hb;

CREATE OR REPLACE VIEW hive.transactions_view AS
SELECT
   ht.block_num,
   ht.trx_in_block,
   ht.trx_hash,
   ht.ref_block_num,
   ht.ref_block_prefix,
   ht.expiration,
   ht.signature
FROM hafd.transactions ht;

CREATE OR REPLACE VIEW hive.operations_view_extended
AS
SELECT
      ho.id,
      hafd.operation_id_to_block_num( ho.id ) as block_num,
      ho.trx_in_block,
      ho.op_pos,
      ho.op_type_id,
      b.created_at timestamp,
      ho.body_binary as body_binary,
      ho.body_binary::jsonb AS body,
      ho.custom_json_type_id
FROM hafd.operations ho
JOIN hafd.blocks b ON b.num = hafd.operation_id_to_block_num(ho.id);

CREATE OR REPLACE VIEW hive.operations_view
AS
SELECT
      ho.id,
      hafd.operation_id_to_block_num( ho.id ) as block_num,
      ho.trx_in_block,
      ho.op_pos,
      ho.op_type_id,
      ho.body_binary as body_binary,
      ho.body_binary::jsonb AS body,
      ho.custom_json_type_id
FROM hafd.operations ho;

CREATE OR REPLACE VIEW hive.transactions_multisig_view
AS
SELECT
      htm.trx_hash
    , htm.signature
FROM hafd.transactions_multisig htm;

CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
  SELECT hr.hardfork_num,
         hr.block_num,
         hr.hardfork_vop_id
  FROM hafd.applied_hardforks hr;

-- only irreversible data
CREATE OR REPLACE VIEW hive.irreversible_account_operations_view AS
    SELECT
       ha.account_id,
       ha.transacting_account_id,
       ha.account_op_seq_no,
       ha.operation_id,
       ha.op_type_id,
       hafd.operation_id_to_block_num( ha.operation_id ) as block_num
    FROM hafd.account_operations ha;

CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS SELECT ha.id, ha.name FROM  hafd.accounts ha;
CREATE OR REPLACE VIEW hive.irreversible_blocks_view AS SELECT * FROM hafd.blocks;
CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS SELECT * FROM hafd.transactions;

CREATE OR REPLACE VIEW hive.irreversible_operations_view_extended AS
    SELECT
        op.id,
        hafd.operation_id_to_block_num( op.id ) as block_num,
        op.trx_in_block,
        op.op_pos,
        op.op_type_id,
        b.created_at timestamp,
        op.body_binary as body_binary,
        op.body_binary::jsonb AS body,
        op.custom_json_type_id
    FROM hafd.operations op
    JOIN hafd.blocks b ON b.num = hafd.operation_id_to_block_num(op.id);

CREATE OR REPLACE VIEW hive.irreversible_operations_view AS
    SELECT
        op.id,
        hafd.operation_id_to_block_num( op.id ) as block_num,
        op.trx_in_block,
        op.op_pos,
        op.op_type_id,
        op.body_binary as body_binary,
        op.body_binary::jsonb AS body,
        op.custom_json_type_id
    FROM hafd.operations op;


CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS SELECT * FROM hafd.transactions_multisig;
CREATE OR REPLACE VIEW hive.irreversible_applied_hardforks_view AS SELECT * FROM hafd.applied_hardforks;
