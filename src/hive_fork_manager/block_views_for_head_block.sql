-- Common CTE for getting consistent block boundary
-- This CTE is used by all views to determine the irreversible/reversible boundary
CREATE OR REPLACE VIEW hive.account_operations_view AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
),
visible_reversible AS (
  SELECT hafd.block_id(hafd.block_id_to_num(block_id), MAX(hafd.block_id_to_fork_id(block_id))) as block_id
  FROM hafd.operations
  CROSS JOIN consistent
  WHERE hafd.block_id_to_num(block_id) > hafd.block_id_to_num(consistent.cid)
  GROUP BY hafd.block_id_to_num(block_id)
)
SELECT ha.account_id,
       ha.transacting_account_id,
       ha.account_op_seq_no,
       ha.operation_id,
       hafd.operation_id_to_type_id( ha.operation_id ) as op_type_id,
       hafd.operation_id_to_block_num( ha.operation_id ) as block_num
FROM hafd.account_operations ha
JOIN hafd.operations ho ON ha.operation_id = ho.id
CROSS JOIN consistent
WHERE hafd.block_id_to_num(ho.block_id) <= hafd.block_id_to_num(consistent.cid)
   OR ho.block_id IN (SELECT block_id FROM visible_reversible);

CREATE OR REPLACE VIEW hive.accounts_view AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
),
visible_reversible AS (
  SELECT hafd.block_id(hafd.block_id_to_num(block_id), MAX(hafd.block_id_to_fork_id(block_id))) as block_id
  FROM hafd.accounts
  CROSS JOIN consistent
  WHERE hafd.block_id_to_num(block_id) > hafd.block_id_to_num(consistent.cid)
  GROUP BY hafd.block_id_to_num(block_id)
)
SELECT ha.id,
       ha.name
FROM hafd.accounts ha
CROSS JOIN consistent
WHERE hafd.block_id_to_num(ha.block_id) <= hafd.block_id_to_num(consistent.cid)
   OR ha.block_id IN (SELECT block_id FROM visible_reversible)
;

CREATE OR REPLACE VIEW hive.blocks_view
AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
),
visible_reversible AS (
  SELECT hafd.block_id(num, MAX(fork_id)) as block_id
  FROM hafd.blocks
  CROSS JOIN consistent
  WHERE num > hafd.block_id_to_num(consistent.cid)
  GROUP BY num
)
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
FROM hafd.blocks hb
CROSS JOIN consistent
WHERE hb.num <= hafd.block_id_to_num(consistent.cid)
   OR hb.block_id IN (SELECT block_id FROM visible_reversible)
;

CREATE OR REPLACE VIEW hive.transactions_view AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
),
visible_reversible AS (
  SELECT hafd.block_id(hafd.block_id_to_num(block_id), MAX(hafd.block_id_to_fork_id(block_id))) as block_id
  FROM hafd.transactions
  CROSS JOIN consistent
  WHERE hafd.block_id_to_num(block_id) > hafd.block_id_to_num(consistent.cid)
  GROUP BY hafd.block_id_to_num(block_id)
)
SELECT
   hafd.block_id_to_num(ht.block_id) as block_num,
   ht.trx_in_block,
   ht.trx_hash,
   ht.ref_block_num,
   ht.ref_block_prefix,
   ht.expiration,
   ht.signature
FROM hafd.transactions ht
CROSS JOIN consistent
WHERE hafd.block_id_to_num(ht.block_id) <= hafd.block_id_to_num(consistent.cid)
   OR ht.block_id IN (SELECT block_id FROM visible_reversible)
;

CREATE OR REPLACE VIEW hive.operations_view_extended
AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
),
visible_reversible AS (
  SELECT hafd.block_id(hafd.block_id_to_num(block_id), MAX(hafd.block_id_to_fork_id(block_id))) as block_id
  FROM hafd.operations
  CROSS JOIN consistent
  WHERE hafd.block_id_to_num(block_id) > hafd.block_id_to_num(consistent.cid)
  GROUP BY hafd.block_id_to_num(block_id)
)
SELECT ho.id,
       hafd.operation_id_to_block_num( ho.id ) as block_num,
       ho.trx_in_block,
       ho.op_pos,
       hafd.operation_id_to_type_id( ho.id ) as op_type_id,
       (SELECT created_at FROM hafd.blocks WHERE block_id = ho.block_id) as timestamp,
       ho.body_binary as body_binary,
       ho.body_binary::jsonb AS body
FROM hafd.operations ho
CROSS JOIN consistent
WHERE hafd.block_id_to_num(ho.block_id) <= hafd.block_id_to_num(consistent.cid)
   OR ho.block_id IN (SELECT block_id FROM visible_reversible);

CREATE OR REPLACE VIEW hive.operations_view
AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
),
visible_reversible AS (
  SELECT hafd.block_id(hafd.block_id_to_num(block_id), MAX(hafd.block_id_to_fork_id(block_id))) as block_id
  FROM hafd.operations
  CROSS JOIN consistent
  WHERE hafd.block_id_to_num(block_id) > hafd.block_id_to_num(consistent.cid)
  GROUP BY hafd.block_id_to_num(block_id)
)
SELECT ho.id,
       hafd.operation_id_to_block_num( ho.id ) as block_num,
       ho.trx_in_block,
       ho.op_pos,
       hafd.operation_id_to_type_id( ho.id ) as op_type_id,
       ho.body_binary
FROM hafd.operations ho
CROSS JOIN consistent
WHERE hafd.block_id_to_num(ho.block_id) <= hafd.block_id_to_num(consistent.cid)
   OR ho.block_id IN (SELECT block_id FROM visible_reversible);

CREATE OR REPLACE VIEW hive.transactions_multisig_view
AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
),
visible_reversible AS (
  SELECT hafd.block_id(hafd.block_id_to_num(block_id), MAX(hafd.block_id_to_fork_id(block_id))) as block_id
  FROM hafd.transactions
  CROSS JOIN consistent
  WHERE hafd.block_id_to_num(block_id) > hafd.block_id_to_num(consistent.cid)
  GROUP BY hafd.block_id_to_num(block_id)
)
SELECT
      htm.trx_hash
    , htm.signature
FROM hafd.transactions_multisig htm
JOIN hafd.transactions ht ON htm.trx_hash = ht.trx_hash
CROSS JOIN consistent
WHERE hafd.block_id_to_num(ht.block_id) <= hafd.block_id_to_num(consistent.cid)
   OR ht.block_id IN (SELECT block_id FROM visible_reversible);

CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
),
visible_reversible AS (
  SELECT hafd.block_id(hafd.block_id_to_num(block_id), MAX(hafd.block_id_to_fork_id(block_id))) as block_id
  FROM hafd.applied_hardforks
  CROSS JOIN consistent
  WHERE hafd.block_id_to_num(block_id) > hafd.block_id_to_num(consistent.cid)
  GROUP BY hafd.block_id_to_num(block_id)
)
SELECT hr.hardfork_num,
       hafd.block_id_to_num(hr.block_id) as block_num,
       hr.hardfork_vop_id
FROM hafd.applied_hardforks hr
CROSS JOIN consistent
WHERE hafd.block_id_to_num(hr.block_id) <= hafd.block_id_to_num(consistent.cid)
   OR hr.block_id IN (SELECT block_id FROM visible_reversible);

-- only irreversible data
-- These views show only blocks that are <= consistent_block_id
CREATE OR REPLACE VIEW hive.irreversible_account_operations_view AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
)
SELECT
   ha.account_id,
   ha.transacting_account_id,
   ha.account_op_seq_no,
   ha.operation_id,
   hafd.operation_id_to_type_id( ha.operation_id ) as op_type_id,
   hafd.operation_id_to_block_num( ha.operation_id ) as block_num
FROM hafd.account_operations ha
JOIN hafd.operations ho ON ha.operation_id = ho.id
CROSS JOIN consistent
WHERE hafd.block_id_to_num(ho.block_id) <= hafd.block_id_to_num(consistent.cid);

CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
)
SELECT ha.id, ha.name 
FROM hafd.accounts ha 
CROSS JOIN consistent
WHERE hafd.block_id_to_num(ha.block_id) <= hafd.block_id_to_num(consistent.cid);
    
CREATE OR REPLACE VIEW hive.irreversible_blocks_view AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
)
SELECT * FROM hafd.blocks
CROSS JOIN consistent
WHERE num <= hafd.block_id_to_num(consistent.cid);

CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
)
SELECT ht.* 
FROM hafd.transactions ht
CROSS JOIN consistent
WHERE hafd.block_id_to_num(ht.block_id) <= hafd.block_id_to_num(consistent.cid);

CREATE OR REPLACE VIEW hive.irreversible_operations_view_extended AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
)
SELECT
    op.id,
    hafd.operation_id_to_block_num( op.id ) as block_num,
    op.trx_in_block,
    op.op_pos,
    hafd.operation_id_to_type_id( op.id ) as op_type_id,
    (SELECT created_at FROM hafd.blocks WHERE block_id = op.block_id) as timestamp,
    op.body_binary as body_binary,
    op.body_binary::jsonb AS body
FROM hafd.operations op
CROSS JOIN consistent
WHERE hafd.block_id_to_num(op.block_id) <= hafd.block_id_to_num(consistent.cid);

CREATE OR REPLACE VIEW hive.irreversible_operations_view AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
)
SELECT
    op.id,
    hafd.operation_id_to_block_num( op.id ) as block_num,
    op.trx_in_block,
    op.op_pos,
    hafd.operation_id_to_type_id( op.id ) as op_type_id,
    op.body_binary as body_binary,
    op.body_binary::jsonb AS body
FROM hafd.operations op
CROSS JOIN consistent
WHERE hafd.block_id_to_num(op.block_id) <= hafd.block_id_to_num(consistent.cid);


CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
)
SELECT htm.* 
FROM hafd.transactions_multisig htm
JOIN hafd.transactions ht ON htm.trx_hash = ht.trx_hash
CROSS JOIN consistent
WHERE hafd.block_id_to_num(ht.block_id) <= hafd.block_id_to_num(consistent.cid);

CREATE OR REPLACE VIEW hive.irreversible_applied_hardforks_view AS
WITH consistent AS (
  SELECT COALESCE(consistent_block_id, 0) as cid FROM hafd.hive_state LIMIT 1
)
SELECT hah.* 
FROM hafd.applied_hardforks hah
CROSS JOIN consistent
WHERE hafd.block_id_to_num(hah.block_id) <= hafd.block_id_to_num(consistent.cid);

