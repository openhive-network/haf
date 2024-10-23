CREATE OR REPLACE VIEW hive.account_operations_view AS
 (
  SELECT ha.account_id,
         ha.account_op_seq_no,
         ha.operation_id,
         hive.operation_id_to_type_id( ha.operation_id ) as op_type_id,
         hive.operation_id_to_block_num( ha.operation_id ) as block_num
  FROM hive_data.account_operations ha
 )
UNION ALL
(
WITH 
consistent_block AS
(SELECT COALESCE(hid.consistent_block, 0) AS consistent_block FROM hive_data.irreversible_data hid LIMIT 1)
,forks AS
(
  SELECT hbr.num, max(hbr.fork_id) AS max_fork_id
  FROM hive_data.blocks_reversible hbr, consistent_block cb
  WHERE hbr.num > cb.consistent_block
  GROUP BY hbr.num
)
SELECT har.account_id,
       har.account_op_seq_no,
       har.operation_id,
       hive.operation_id_to_type_id( har.operation_id ) as op_type_id,
       hive.operation_id_to_block_num( har.operation_id ) as block_num
FROM forks 
JOIN hive_data.operations_reversible hor ON forks.max_fork_id = hor.fork_id AND forks.num = hive.operation_id_to_block_num(hor.id)
JOIN hive_data.account_operations_reversible har ON forks.max_fork_id = har.fork_id AND har.operation_id = hor.id -- We can consider to extend account_operations_reversible by block_num column and eliminate need to join operations_reversible
);

CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT
    t.id,
    t.name
FROM
(
    SELECT
        ha.id,
        ha.name
    FROM hive_data.accounts ha
    UNION ALL
    SELECT
        reversible.id,
        reversible.name
    FROM (
        SELECT
            har.id,
            har.name,
            har.fork_id
        FROM hive_data.accounts_reversible har
        JOIN (
            SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
            FROM hive_data.blocks_reversible hbr
            WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive_data.irreversible_data hid )
            GROUP by hbr.num
        ) as forks ON forks.max_fork_id = har.fork_id AND forks.num = har.block_num
    ) reversible
) t
;

CREATE OR REPLACE VIEW hive.blocks_view
AS
SELECT t.num,
       t.hash,
       t.prev,
       t.created_at,
       t.producer_account_id,
       t.transaction_merkle_root,
       t.extensions,
       t.witness_signature,
       t.signing_key,
       t.hbd_interest_rate,
       t.total_vesting_fund_hive,
       t.total_vesting_shares,
       t.total_reward_fund_hive,
       t.virtual_supply,
       t.current_supply,
       t.current_hbd_supply,
       t.dhf_interval_ledger
FROM (
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
    FROM hive_data.blocks hb
    UNION ALL
    SELECT hbr.num,
        hbr.hash,
        hbr.prev,
        hbr.created_at,
        hbr.producer_account_id,
        hbr.transaction_merkle_root,
        hbr.extensions,
        hbr.witness_signature,
        hbr.signing_key,
        hbr.hbd_interest_rate,
        hbr.total_vesting_fund_hive,
        hbr.total_vesting_shares,
        hbr.total_reward_fund_hive,
        hbr.virtual_supply,
        hbr.current_supply,
        hbr.current_hbd_supply,
        hbr.dhf_interval_ledger
    FROM hive_data.blocks_reversible hbr
    JOIN
    (
         SELECT rb.num, MAX(rb.fork_id) AS max_fork_id
         FROM hive_data.blocks_reversible rb
         WHERE rb.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive_data.irreversible_data hid )
         GROUP BY rb.num
    ) visible_blks ON visible_blks.num = hbr.num AND visible_blks.max_fork_id = hbr.fork_id
) t
;

CREATE OR REPLACE VIEW hive.transactions_view AS
SELECT
   t.block_num,
   t.trx_in_block,
   t.trx_hash,
   t.ref_block_num,
   t.ref_block_prefix,
   t.expiration,
   t.signature
FROM
(
    SELECT ht.block_num,
           ht.trx_in_block,
           ht.trx_hash,
           ht.ref_block_num,
           ht.ref_block_prefix,
           ht.expiration,
           ht.signature
    FROM hive_data.transactions ht
    UNION ALL
    SELECT reversible.block_num,
            reversible.trx_in_block,
            reversible.trx_hash,
            reversible.ref_block_num,
            reversible.ref_block_prefix,
            reversible.expiration,
            reversible.signature
    FROM ( SELECT
            htr.block_num,
            htr.trx_in_block,
            htr.trx_hash,
            htr.ref_block_num,
            htr.ref_block_prefix,
            htr.expiration,
            htr.signature,
            htr.fork_id
    FROM hive_data.transactions_reversible htr
    JOIN (
        SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
        FROM hive_data.blocks_reversible hbr
        WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive_data.irreversible_data hid )
        GROUP by hbr.num
    ) as forks ON forks.max_fork_id = htr.fork_id AND forks.num = htr.block_num
    ) reversible
) t
;

CREATE OR REPLACE VIEW hive.operations_view_extended
AS
SELECT t.id,
       hive.operation_id_to_block_num( t.id ) as block_num,
       t.trx_in_block,
       t.op_pos,
       hive.operation_id_to_type_id( t.id ) as op_type_id,
       t.timestamp,
       CAST( t.body_binary AS hive.operation ) as body_binary,
       t.body
FROM
(
    SELECT
          ho.id,
          ho.trx_in_block,
          ho.op_pos,
          b.created_at timestamp,
          ho.body_binary,
          ho.body_binary::jsonb AS body
    FROM hive_data.operations ho
    JOIN hive_data.blocks b ON b.num = hive.operation_id_to_block_num(ho.id)
    UNION ALL
      SELECT
        o.id,
        o.trx_in_block,
        o.op_pos,
        visible_ops_timestamp.created_at timestamp,
        o.body_binary,
        o.body_binary::jsonb AS body
        FROM hive_data.operations_reversible o
      -- Reversible operations view must show ops comming from newest fork (specific to app-context)
      -- and also hide ops present at earlier forks for given block
      JOIN
      (
        SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
        FROM hive_data.blocks_reversible hbr
        WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive_data.irreversible_data hid )
        GROUP by hbr.num
      ) visible_ops on visible_ops.num = hive.operation_id_to_block_num(o.id) and visible_ops.max_fork_id = o.fork_id
      JOIN
      (
        SELECT hbr.num, created_at
        FROM hive_data.blocks_reversible hbr
      ) visible_ops_timestamp ON visible_ops_timestamp.num = visible_ops.num
) t
;

CREATE OR REPLACE VIEW hive.operations_view
AS
SELECT t.id,
       hive.operation_id_to_block_num( t.id ) as block_num,
       t.trx_in_block,
       t.op_pos,
       hive.operation_id_to_type_id( t.id ) as op_type_id,
       CAST( t.body_binary AS hive.operation ) as body_binary,
       t.body
FROM
(
    SELECT
          ho.id,
          ho.trx_in_block,
          ho.op_pos,
          ho.body_binary,
          ho.body_binary::jsonb AS body
    FROM hive_data.operations ho
    UNION ALL
      SELECT
        o.id,
        o.trx_in_block,
        o.op_pos,
        o.body_binary,
        o.body_binary::jsonb AS body
      FROM hive_data.operations_reversible o
      -- Reversible operations view must show ops comming from newest fork (specific to app-context)
      -- and also hide ops present at earlier forks for given block
      JOIN
      (
        SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
        FROM hive_data.blocks_reversible hbr
        WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive_data.irreversible_data hid )
        GROUP by hbr.num
      ) visible_ops on visible_ops.num = hive.operation_id_to_block_num(o.id) and visible_ops.max_fork_id = o.fork_id
) t
;

CREATE OR REPLACE VIEW hive.transactions_multisig_view
AS
SELECT
      t.trx_hash
    , t.signature
FROM (
    SELECT
          htm.trx_hash
        , htm.signature
    FROM hive_data.transactions_multisig htm
    UNION ALL
    SELECT
           reversible.trx_hash
         , reversible.signature
    FROM (
        SELECT
               htmr.trx_hash
             , htmr.signature
        FROM hive_data.transactions_multisig_reversible htmr
        JOIN (
                SELECT htr.trx_hash, forks.max_fork_id
                FROM hive_data.transactions_reversible htr
                JOIN (
                    SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
                    FROM hive_data.blocks_reversible hbr
                    WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive_data.irreversible_data hid )
                    GROUP by hbr.num
                ) as forks ON forks.max_fork_id = htr.fork_id AND forks.num = htr.block_num
        ) as trr ON trr.trx_hash = htmr.trx_hash AND trr.max_fork_id = htmr.fork_id
    ) reversible
) t;

CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
 (
  SELECT hr.hardfork_num,
         hr.block_num,
         hr.hardfork_vop_id
  FROM hive_data.applied_hardforks hr
 )
UNION ALL
(
WITH 
consistent_block AS
(SELECT COALESCE(hid.consistent_block, 0) AS consistent_block FROM hive_data.irreversible_data hid LIMIT 1)
,forks AS
(
  SELECT hbr.num, max(hbr.fork_id) AS max_fork_id
  FROM hive_data.blocks_reversible hbr, consistent_block cb
  WHERE hbr.num > cb.consistent_block
  GROUP BY hbr.num
)
SELECT hjr.hardfork_num,
       hjr.block_num,
       hjr.hardfork_vop_id
FROM forks 
JOIN hive_data.operations_reversible hor ON forks.max_fork_id = hor.fork_id AND forks.num = hive.operation_id_to_block_num(hor.id)
JOIN hive_data.applied_hardforks_reversible hjr ON forks.max_fork_id = hjr.fork_id AND hjr.hardfork_vop_id = hor.id -- We can consider to extend account_operations_reversible by block_num column and eliminate need to join operations_reversible
);

-- only irreversible data
CREATE OR REPLACE VIEW hive.irreversible_account_operations_view AS
    SELECT
       ha.account_id,
       ha.account_op_seq_no,
       ha.operation_id,
       hive.operation_id_to_type_id( ha.operation_id ) as op_type_id,
       hive.operation_id_to_block_num( ha.operation_id ) as block_num
    FROM hive_data.account_operations ha;

CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS SELECT ha.id, ha.name FROM  hive_data.accounts ha;
CREATE OR REPLACE VIEW hive.irreversible_blocks_view AS SELECT * FROM hive_data.blocks;
CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS SELECT * FROM hive_data.transactions;

CREATE OR REPLACE VIEW hive.irreversible_operations_view_extended AS
    SELECT
        op.id,
        hive.operation_id_to_block_num( op.id ) as block_num,
        op.trx_in_block,
        op.op_pos,
        hive.operation_id_to_type_id( op.id ) as op_type_id,
        b.created_at timestamp,
        CAST( op.body_binary AS hive.operation ) as body_binary,
        op.body_binary::jsonb AS body
    FROM hive_data.operations op
    JOIN hive_data.blocks b ON b.num = hive.operation_id_to_block_num(op.id);

CREATE OR REPLACE VIEW hive.irreversible_operations_view AS
    SELECT
        op.id,
        hive.operation_id_to_block_num( op.id ) as block_num,
        op.trx_in_block,
        op.op_pos,
        hive.operation_id_to_type_id( op.id ) as op_type_id,
        CAST( op.body_binary AS hive.operation ) as body_binary,
        op.body_binary::jsonb AS body
    FROM hive_data.operations op;


CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS SELECT * FROM hive_data.transactions_multisig;
CREATE OR REPLACE VIEW hive.irreversible_applied_hardforks_view AS SELECT * FROM hive_data.applied_hardforks;
