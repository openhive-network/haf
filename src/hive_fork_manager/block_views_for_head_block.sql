-- Full views are built from irreversible views plus reversible tables

CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS SELECT ha.id, ha.name FROM  hafd.accounts ha;
CREATE OR REPLACE VIEW hive.accounts_view AS
    SELECT * from hive.irreversible_accounts_view -- irreversible accounts view
    UNION ALL
    SELECT
        reversible.id,
        reversible.name
    FROM (
        SELECT
            har.id,
            har.name,
            har.fork_id
        FROM hafd.accounts_reversible har
        JOIN (
            SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
            FROM hafd.blocks_reversible hbr
            WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hafd.hive_state hid )
            GROUP by hbr.num
        ) as forks ON forks.max_fork_id = har.fork_id AND forks.num = har.block_num
    ) reversible
;

CREATE OR REPLACE VIEW hive.irreversible_blocks_view AS SELECT * FROM hafd.blocks;
CREATE OR REPLACE VIEW hive.blocks_view
    SELECT * FROM hive.irreversible_blocks_view AS
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
    FROM hafd.blocks_reversible hbr
    JOIN
    (
         SELECT rb.num, MAX(rb.fork_id) AS max_fork_id
         FROM hafd.blocks_reversible rb
         WHERE rb.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hafd.hive_state hid )
         GROUP BY rb.num
    ) visible_blks ON visible_blks.num = hbr.num AND visible_blks.max_fork_id = hbr.fork_id
;

CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS SELECT * FROM hafd.transactions;
CREATE OR REPLACE VIEW hive.transactions_view AS
    SELECT * FROM hive.irreversible_transactions_view
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
    FROM hafd.transactions_reversible htr
    JOIN (
        SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
        FROM hafd.blocks_reversible hbr
        WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hafd.hive_state hid )
        GROUP by hbr.num
    ) as forks ON forks.max_fork_id = htr.fork_id AND forks.num = htr.block_num
    ) reversible
;

CREATE OR REPLACE VIEW hive.irreversible_operations_view_extended AS
    SELECT
        op.id,
        hafd.operation_id_to_block_num( op.id ) as block_num,
        op.trx_in_block,
        op.op_pos,
        hafd.operation_id_to_type_id( op.id ) as op_type_id,
        b.created_at timestamp,
        op.body_binary as body_binary,
        op.body_binary::jsonb AS body
    FROM hafd.operations op
    JOIN hafd.blocks b ON b.num = hafd.operation_id_to_block_num(op.id);
CREATE OR REPLACE VIEW hive.operations_view_extended AS
    SELECT * from hive.irreversible_operations_view_extended 
    UNION ALL
    SELECT
        opr.id,
        hafd.operation_id_to_block_num( opr.id ) as block_num,
        opr.trx_in_block,
        opr.op_pos,
        hafd.operation_id_to_type_id( opr.id ) as op_type_id,
        visible_ops_timestamp.created_at timestamp,
        opr.body_binary,
        opr.body_binary::jsonb AS body
        FROM hafd.operations_reversible opr
      -- Reversible operations view must show ops comming from newest fork (specific to app-context)
      -- and also hide ops present at earlier forks for given block
      JOIN
      (
        SELECT num, MAX(fork_id) as max_fork_id
        FROM hafd.blocks_reversible
        WHERE num > ( SELECT COALESCE( consistent_block, 0 ) FROM hafd.hive_state )
        GROUP by num
      ) visible_ops on visible_ops.num = hafd.operation_id_to_block_num(opr.id) and visible_ops.max_fork_id = opr.fork_id
      JOIN
      (
        SELECT num, created_at
        FROM hafd.blocks_reversible
      ) visible_ops_timestamp ON visible_ops_timestamp.num = visible_ops.num
;


CREATE OR REPLACE VIEW hive.irreversible_operations_view AS
    SELECT
        op.id,
        hafd.operation_id_to_block_num( op.id ) as block_num,
        op.trx_in_block,
        op.op_pos,
        hafd.operation_id_to_type_id( op.id ) as op_type_id,
        op.body_binary as body_binary,
        op.body_binary::jsonb AS body
    FROM hafd.operations op;
-- irreversible PLUS irreversible operations
CREATE OR REPLACE VIEW hive.operations_view AS
    SELECT * from hive.irreversible_operations_view -- irreversible operations view
    UNION ALL
      SELECT
        o.id,
        hafd.operation_id_to_block_num( o.id ) as block_num,
        o.trx_in_block,
        o.op_pos,
        hafd.operation_id_to_type_id( o.id ) as op_type_id,
        o.body_binary,
        o.body_binary::jsonb AS body
      FROM hafd.operations_reversible o
      -- Reversible operations view must show ops comming from newest fork (specific to app-context)
      -- and also hide ops present at earlier forks for given block
      JOIN
      (
        SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
        FROM hafd.blocks_reversible hbr
        WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hafd.hive_state hid )
        GROUP by hbr.num
      ) visible_ops on visible_ops.num = hafd.operation_id_to_block_num(o.id) and visible_ops.max_fork_id = o.fork_id
;

CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS SELECT * FROM hafd.transactions_multisig;
CREATE OR REPLACE VIEW hive.transactions_multisig_view AS
    SELECT * FROM hive.irreversible_transactions_multisig_view
    UNION ALL
    SELECT
        reversible.trx_hash,
        reversible.signature
    FROM (
        SELECT
               htmr.trx_hash
             , htmr.signature
        FROM hafd.transactions_multisig_reversible htmr
        JOIN (
                SELECT htr.trx_hash, forks.max_fork_id
                FROM hafd.transactions_reversible htr
                JOIN (
                    SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
                    FROM hafd.blocks_reversible hbr
                    WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hafd.hive_state hid )
                    GROUP by hbr.num
                ) as forks ON forks.max_fork_id = htr.fork_id AND forks.num = htr.block_num
        ) as trr ON trr.trx_hash = htmr.trx_hash AND trr.max_fork_id = htmr.fork_id
    ) reversible;

CREATE OR REPLACE VIEW hive.irreversible_applied_hardforks_view AS SELECT * FROM hafd.applied_hardforks;
CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
    SELECT * FROM hive.irreversible_applied_hardforks_view 
    UNION ALL
    (
    WITH 
    consistent_block AS
    (SELECT COALESCE(hid.consistent_block, 0) AS consistent_block FROM hafd.hive_state hid LIMIT 1)
    ,forks AS
    (
    SELECT hbr.num, max(hbr.fork_id) AS max_fork_id
    FROM hafd.blocks_reversible hbr, consistent_block cb
    WHERE hbr.num > cb.consistent_block
    GROUP BY hbr.num
    )
    SELECT hjr.hardfork_num,
        hjr.block_num,
        hjr.hardfork_vop_id
    FROM forks 
    JOIN hafd.operations_reversible hor ON forks.max_fork_id = hor.fork_id AND forks.num = hafd.operation_id_to_block_num(hor.id)
    JOIN hafd.applied_hardforks_reversible hjr ON forks.max_fork_id = hjr.fork_id AND hjr.hardfork_vop_id = hor.id -- We can consider to extend account_operations_reversible by block_num column and eliminate need to join operations_reversible
    );


-- CONSIDER MOVING THIS VIEW AND THE ACCOUNT OPERATIONS TABLE TO HAFAH EVENTUALLY (normal app indexers should not need it)
-- only irreversible account operations
CREATE OR REPLACE VIEW hive.irreversible_account_operations_view AS
    SELECT
       ha.account_id,
       ha.account_op_seq_no,
       ha.operation_id,
       hafd.operation_id_to_type_id( ha.operation_id ) as op_type_id,
       hafd.operation_id_to_block_num( ha.operation_id ) as block_num
    FROM hafd.account_operations ha;
-- irreversible PLUS irreversible account operations
CREATE OR REPLACE VIEW hive.account_operations_view AS
    SELECT * FROM hive.irreversible_account_operations_view
    UNION ALL
    (
    WITH consistent_block AS
    (SELECT COALESCE(consistent_block, 0) AS consistent_block FROM hafd.hive_state LIMIT 1)
    ,forks AS
    (
    SELECT hbr.num, max(hbr.fork_id) AS max_fork_id
    FROM hafd.blocks_reversible hbr, consistent_block cb
    WHERE hbr.num > cb.consistent_block
    GROUP BY hbr.num
    )
    SELECT har.account_id,
        har.account_op_seq_no,
        har.operation_id,
        hafd.operation_id_to_type_id( har.operation_id ) as op_type_id,
        hafd.operation_id_to_block_num( har.operation_id ) as block_num
    FROM forks 
    JOIN hafd.operations_reversible hor ON forks.max_fork_id = hor.fork_id AND forks.num = hafd.operation_id_to_block_num(hor.id)
    JOIN hafd.account_operations_reversible har ON forks.max_fork_id = har.fork_id AND har.operation_id = hor.id -- We can consider to extend account_operations_reversible by block_num column and eliminate need to join operations_reversible
    );


