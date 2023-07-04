CREATE OR REPLACE VIEW hive.account_operations_view AS
 (
  SELECT ha.account_id,
         ha.account_op_seq_no,
         ha.operation_id,
         ha.op_type_id,
         ha.block_num
  FROM hive.account_operations ha
 )
UNION ALL
(
WITH 
consistent_block AS
(SELECT COALESCE(hid.consistent_block, 0) AS consistent_block FROM hive.irreversible_data hid LIMIT 1)
,forks AS
(
  SELECT hbr.num, max(hbr.fork_id) AS max_fork_id
  FROM hive.blocks_reversible hbr, consistent_block cb
  WHERE hbr.num > cb.consistent_block
  GROUP BY hbr.num
)
SELECT har.account_id,
       har.account_op_seq_no,
       har.operation_id,
       har.op_type_id,
       har.block_num
FROM forks 
JOIN hive.operations_reversible hor ON forks.max_fork_id = hor.fork_id AND forks.num = hor.block_num
JOIN hive.account_operations_reversible har ON forks.max_fork_id = har.fork_id AND har.operation_id = hor.id -- We can consider to extend account_operations_reversible by block_num column and eliminate need to join operations_reversible
);

CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT
    t.block_num,
    t.id,
    t.name
FROM
(
    SELECT
        ha.block_num,
        ha.id,
        ha.name
    FROM hive.accounts ha
    UNION ALL
    SELECT
        reversible.block_num,
        reversible.id,
        reversible.name
    FROM (
        SELECT
            har.block_num,
            har.id,
            har.name,
            har.fork_id
        FROM hive.accounts_reversible har
        JOIN (
            SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
            FROM hive.blocks_reversible hbr
            WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive.irreversible_data hid )
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
    FROM hive.blocks hb
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
    FROM hive.blocks_reversible hbr
    JOIN
    (
         SELECT rb.num, MAX(rb.fork_id) AS max_fork_id
         FROM hive.blocks_reversible rb
         WHERE rb.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive.irreversible_data hid )
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
    FROM hive.transactions ht
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
    FROM hive.transactions_reversible htr
    JOIN (
        SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
        FROM hive.blocks_reversible hbr
        WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive.irreversible_data hid )
        GROUP by hbr.num
    ) as forks ON forks.max_fork_id = htr.fork_id AND forks.num = htr.block_num
    ) reversible
) t
;

CREATE OR REPLACE VIEW hive.operations_view
AS
SELECT t.id,
       t.block_num,
       t.trx_in_block,
       t.op_pos,
       t.op_type_id,
       t.timestamp,
       t.body_binary,
       t.body
FROM
(
    SELECT
          ho.id,
          ho.block_num,
          ho.trx_in_block,
          ho.op_pos,
          ho.op_type_id,
          ho.timestamp,
          ho.body_binary,
          ho.body_binary::jsonb AS body
    FROM hive.operations ho
    UNION ALL
      SELECT
        o.id,
        o.block_num,
        o.trx_in_block,
        o.op_pos,
        o.op_type_id,
        o.timestamp,
        o.body_binary,
        o.body_binary::jsonb AS body
      FROM hive.operations_reversible o
      -- Reversible operations view must show ops comming from newest fork (specific to app-context)
      -- and also hide ops present at earlier forks for given block
      JOIN
      (
        SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
        FROM hive.blocks_reversible hbr
        WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive.irreversible_data hid )
        GROUP by hbr.num
      ) visible_ops on visible_ops.num = o.block_num and visible_ops.max_fork_id = o.fork_id
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
    FROM hive.transactions_multisig htm
    UNION ALL
    SELECT
           reversible.trx_hash
         , reversible.signature
    FROM (
        SELECT
               htmr.trx_hash
             , htmr.signature
        FROM hive.transactions_multisig_reversible htmr
        JOIN (
                SELECT htr.trx_hash, forks.max_fork_id
                FROM hive.transactions_reversible htr
                JOIN (
                    SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
                    FROM hive.blocks_reversible hbr
                    WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive.irreversible_data hid )
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
  FROM hive.applied_hardforks hr
 )
UNION ALL
(
WITH 
consistent_block AS
(SELECT COALESCE(hid.consistent_block, 0) AS consistent_block FROM hive.irreversible_data hid LIMIT 1)
,forks AS
(
  SELECT hbr.num, max(hbr.fork_id) AS max_fork_id
  FROM hive.blocks_reversible hbr, consistent_block cb
  WHERE hbr.num > cb.consistent_block
  GROUP BY hbr.num
)
SELECT hjr.hardfork_num,
       hjr.block_num,
       hjr.hardfork_vop_id
FROM forks 
JOIN hive.operations_reversible hor ON forks.max_fork_id = hor.fork_id AND forks.num = hor.block_num
JOIN hive.applied_hardforks_reversible hjr ON forks.max_fork_id = hjr.fork_id AND hjr.hardfork_vop_id = hor.id -- We can consider to extend account_operations_reversible by block_num column and eliminate need to join operations_reversible
);
