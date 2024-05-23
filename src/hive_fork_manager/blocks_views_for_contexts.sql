CREATE OR REPLACE FUNCTION hive.create_context_data_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.context_data_view AS
        SELECT
        hc.current_block_num,
        hc.irreversible_block,
        hc.is_attached,
        hc.fork_id,
        /*
            Definition of `min_block` (from least(current_block_num, irrecersible_block)) has been changed because of creation of gap,
            between app irreversible block and app reversibble blocks which are no longer in hive.reversible blocks,
            because of delay of processing blocks, which can be long enough, that blocks are no longer avaiable in previously mentioned table,
            but are in hive.blocks.
        */
        LEAST(
              hc.irreversible_block
            , hc.current_block_num
        ) AS min_block,
        hc.current_block_num > hc.irreversible_block AND hc.is_forking AS reversible_range
        FROM hive.contexts hc
        WHERE hc.name::text = ''%s''::text
        limit 1
        ;', __schema, _context_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_context_data_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format( 'DROP VIEW IF EXISTS %s.context_data_view CASCADE;', __schema );
END;
$BODY$
;

--- Function required to preserve valid ownership (the role being an owner of app-context) when view has been rebuilt
--- because of automatic detach process (while performing maintenance actions where different database role is used)
CREATE OR REPLACE FUNCTION hive.adjust_view_ownership( _context_name TEXT, _view_base_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
  __owner_name NAME;
  __schema TEXT;
BEGIN
  SELECT c.owner, c.schema INTO __owner_name, __schema FROM hive.contexts c WHERE c.name = _context_name;

  EXECUTE format('ALTER VIEW %s.%s OWNER TO %s;', __schema, _view_base_name, __owner_name);

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_blocks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;

    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.blocks_view
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
        FROM %s.context_data_view c,
        LATERAL ( SELECT hb.num,
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
           WHERE hb.num <= c.min_block
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
             WHERE c.reversible_range AND rb.num > c.irreversible_block AND rb.fork_id <= c.fork_id AND rb.num <= c.current_block_num
             GROUP BY rb.num
           ) visible_blks ON visible_blks.num = hbr.num AND visible_blks.max_fork_id = hbr.fork_id

        ) t;
        ;', __schema, __schema
    );

    PERFORM hive.adjust_view_ownership(_context_name, 'blocks_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_blocks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
SELECT hc.schema INTO __schema
FROM hive.contexts hc
WHERE hc.name = _context_name;

EXECUTE format(
        'CREATE OR REPLACE VIEW %s.blocks_view
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
        FROM hive.blocks hb
        ;', __schema
    );

    PERFORM hive.adjust_view_ownership(_context_name, 'blocks_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_blocks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
SELECT hc.schema INTO __schema
FROM hive.contexts hc
WHERE hc.name = _context_name;
EXECUTE format( 'DROP VIEW IF EXISTS %s.blocks_view CASCADE;', __schema );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_transactions_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
SELECT hc.schema INTO __schema
FROM hive.contexts hc
WHERE hc.name = _context_name;
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.transactions_view AS
        SELECT t.block_num,
           t.trx_in_block,
           t.trx_hash,
           t.ref_block_num,
           t.ref_block_prefix,
           t.expiration,
           t.signature
        FROM %s.context_data_view c,
        LATERAL
        (
          SELECT ht.block_num,
                   ht.trx_in_block,
                   ht.trx_hash,
                   ht.ref_block_num,
                   ht.ref_block_prefix,
                   ht.expiration,
                   ht.signature
                FROM hive.transactions ht
                WHERE ht.block_num <= c.min_block
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
                    WHERE c.reversible_range AND hbr.num > c.irreversible_block AND hbr.fork_id <= c.fork_id AND hbr.num <= c.current_block_num
                    GROUP by hbr.num
                ) as forks ON forks.max_fork_id = htr.fork_id AND forks.num = htr.block_num
             ) reversible
        ) t
        ;'
    , __schema, __schema, _context_name
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'transactions_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_transactions_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
SELECT hc.schema INTO __schema
FROM hive.contexts hc
WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.transactions_view AS
        SELECT ht.block_num,
           ht.trx_in_block,
           ht.trx_hash,
           ht.ref_block_num,
           ht.ref_block_prefix,
           ht.expiration,
           ht.signature
        FROM hive.transactions ht
       ;'
    , __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'transactions_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_transactions_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
SELECT hc.schema INTO __schema
FROM hive.contexts hc
WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.transactions_view CASCADE;', __schema );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view
         AS
         SELECT t.id,
            hive.operation_id_to_block_num( t.id ) as block_num,
            t.trx_in_block,
            t.op_pos,
            hive.operation_id_to_type_id( t.id ) as op_type_id,
            t.body_binary,
            t.body_binary::jsonb AS body
          FROM %s.context_data_view c,
          LATERAL
          (
            SELECT
              ho.id,
              ho.trx_in_block,
              ho.op_pos,
              ho.body_binary
              FROM hive.operations ho
              WHERE hive.operation_id_to_block_num(ho.id) <= c.min_block
            UNION ALL
              SELECT
                o.id,
                o.trx_in_block,
                o.op_pos,
                o.body_binary
              FROM hive.operations_reversible o
              -- Reversible operations view must show ops comming from newest fork (specific to app-context)
              -- and also hide ops present at earlier forks for given block
              JOIN
              (
                SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
                FROM hive.blocks_reversible hbr
                WHERE c.reversible_range AND hbr.num > c.irreversible_block AND hbr.fork_id <= c.fork_id AND hbr.num <= c.current_block_num
                GROUP by hbr.num
              ) visible_ops on visible_ops.num = hive.operation_id_to_block_num(o.id) and visible_ops.max_fork_id = o.fork_id
        ) t
        ;', __schema, __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'operations_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view
         AS
         SELECT
            ho.id,
            hive.operation_id_to_block_num( ho.id ) as block_num,
            ho.trx_in_block,
            ho.op_pos,
            hive.operation_id_to_type_id( ho.id ) as op_type_id,
            ho.body_binary,
            ho.body_binary::jsonb AS body
        FROM hive.operations ho
        ;', __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'operations_view');
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.drop_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.operations_view CASCADE;', __schema );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_signatures_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
    'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW
    AS
    SELECT
          t.trx_hash
        , t.signature
    FROM %s.context_data_view c,
    LATERAL(
        SELECT
                  htm.trx_hash
                , htm.signature
        FROM hive.transactions_multisig htm
        JOIN hive.transactions ht ON ht.trx_hash = htm.trx_hash
        WHERE ht.block_num <= c.min_block
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
                        WHERE c.reversible_range AND hbr.num > c.irreversible_block AND hbr.fork_id <= c.fork_id AND hbr.num <= c.current_block_num
                        GROUP by hbr.num
                    ) as forks ON forks.max_fork_id = htr.fork_id AND forks.num = htr.block_num
            ) as trr ON trr.trx_hash = htmr.trx_hash AND trr.max_fork_id = htmr.fork_id
        ) reversible
        ) t;'
        , __schema, __schema, _context_name, _context_name
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'TRANSACTIONS_MULTISIG_VIEW');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_signatures_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
    'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW
    AS
    SELECT
          htm.trx_hash
        , htm.signature
    FROM hive.transactions_multisig htm
    ;'
    , __schema
    );

    PERFORM hive.adjust_view_ownership(_context_name, 'TRANSACTIONS_MULTISIG_VIEW');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_signatures_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.TRANSACTIONS_MULTISIG_VIEW CASCADE;', __schema );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_accounts_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.accounts_view AS
        SELECT
           t.id,
           t.name
        FROM %s.context_data_view c,
        LATERAL
        (
          SELECT ha.id,
                 ha.name
                FROM hive.accounts ha
                WHERE COALESCE(ha.block_num,1) <= c.min_block
                UNION ALL
                SELECT
                    reversible.id,
                    reversible.name
                FROM ( SELECT
                    har.id,
                    har.name,
                    har.fork_id
                FROM hive.accounts_reversible har
                JOIN (
                    SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
                    FROM hive.blocks_reversible hbr
                    WHERE c.reversible_range AND hbr.num > c.irreversible_block AND hbr.fork_id <= c.fork_id AND hbr.num <= c.current_block_num
                    GROUP by hbr.num
                ) as forks ON forks.max_fork_id = har.fork_id AND forks.num = har.block_num
             ) reversible
        ) t
        ;'
    , __schema, __schema, _context_name
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'accounts_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_accounts_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.accounts_view AS
        SELECT
           ha.id,
           ha.name
        FROM hive.accounts ha
    ;', __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'accounts_view');
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.drop_accounts_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format( 'DROP VIEW IF EXISTS %s.accounts_view CASCADE;', __schema );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_account_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.account_operations_view AS
        SELECT
           hive.operation_id_to_block_num( t.operation_id ) as block_num,
           t.account_id,
           t.account_op_seq_no,
           t.operation_id,
           hive.operation_id_to_type_id( t.operation_id ) as op_type_id
        FROM %s.context_data_view c,
        LATERAL
        (
          SELECT
                 ha.account_id,
                 ha.account_op_seq_no,
                 ha.operation_id
                FROM hive.account_operations ha
                WHERE hive.operation_id_to_block_num(ha.operation_id) <= c.min_block
                UNION ALL
                SELECT
                    reversible.account_id,
                    reversible.account_op_seq_no,
                    reversible.operation_id
                FROM ( SELECT
                    har.account_id,
                    har.account_op_seq_no,
                    har.operation_id,
                    har.fork_id
                FROM hive.account_operations_reversible har
                JOIN (
                        SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
                        FROM hive.blocks_reversible hbr
                        WHERE c.reversible_range AND hbr.num > c.irreversible_block AND hbr.fork_id <= c.fork_id AND hbr.num <= c.current_block_num
                        GROUP by hbr.num
                ) as arr ON arr.max_fork_id = har.fork_id AND arr.num = hive.operation_id_to_block_num( har.operation_id )
             ) reversible
        ) t
        ;'
    , __schema, __schema, _context_name
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'account_operations_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_account_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.account_operations_view AS
        SELECT
           hive.operation_id_to_block_num( ha.operation_id ) as block_num,
           ha.account_id,
           ha.account_op_seq_no,
           ha.operation_id,
           hive.operation_id_to_type_id( ha.operation_id ) as op_type_id
        FROM hive.account_operations ha
        ;'
    , __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'account_operations_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_account_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.account_operations_view CASCADE;', __schema );
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.create_applied_hardforks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
        SELECT
           t.hardfork_num,
           t.block_num,
           t.hardfork_vop_id
        FROM %s.context_data_view c,
        LATERAL
        (
          SELECT hr.hardfork_num,
                 hr.block_num,
                 hr.hardfork_vop_id
                FROM hive.applied_hardforks hr
                WHERE hr.block_num <= c.min_block
                UNION ALL
                SELECT
                    reversible.hardfork_num,
                    reversible.block_num,
                    reversible.hardfork_vop_id
                FROM ( SELECT
                    hjr.hardfork_num,
                    hjr.block_num,
                    hjr.hardfork_vop_id,
                    hjr.fork_id
                FROM hive.applied_hardforks_reversible hjr
                JOIN (
                    SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
                    FROM hive.blocks_reversible hbr
                    WHERE c.reversible_range AND hbr.num > c.irreversible_block AND hbr.fork_id <= c.fork_id AND hbr.num <= c.current_block_num
                    GROUP by hbr.num
                    ) as hfrr ON hfrr.max_fork_id = hjr.fork_id AND hfrr.num = hjr.block_num
             ) reversible
        ) t
        ;'
    , __schema, __schema, _context_name
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'applied_hardforks_view');
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.create_all_irreversible_applied_hardforks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
        SELECT
                 hr.hardfork_num,
                 hr.block_num,
                 hr.hardfork_vop_id
        FROM hive.applied_hardforks hr
        ;'
    , __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'applied_hardforks_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_applied_hardforks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hive.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.applied_hardforks_view;', __schema );
END;
$BODY$
;
