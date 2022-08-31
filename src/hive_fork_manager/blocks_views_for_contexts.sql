CREATE OR REPLACE FUNCTION hive.create_context_data_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
PERFORM hive.dlog(_context_name, 'Entering create_context_data_view');
EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_context_data_view AS
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
            (SELECT num FROM hive.blocks_reversible ORDER BY num ASC LIMIT 1), -- thanks to this, there will be no duplicates
            hc.current_block_num
        ) AS min_block,
        hc.current_block_num > hc.irreversible_block and exists (SELECT NULL::text FROM hive.registered_tables hrt
                                              WHERE hrt.context_id = hc.id)
        AS reversible_range
        FROM hive.contexts hc
        WHERE hc.name::text = ''%s''::text
        limit 1
        ;', _context_name, _context_name
    );
    PERFORM hive.dlog(_context_name, 'Exiting create_context_data_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_context_data_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN

PERFORM hive.dlog(_context_name, 'Entering drop_context_data_view');
EXECUTE format( 'DROP VIEW IF EXISTS hive.%s_context_data_view CASCADE;', _context_name );
PERFORM hive.dlog(_context_name, 'Exiting drop_context_data_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_blocks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.dlog(_context_name, 'Entering create_blocks_view');
    EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_blocks_view
        AS
        SELECT t.num,
            t.hash,
            t.prev,
            t.created_at,
            t.producer_account_id,
            t.transaction_merkle_root,
            t.extensions,
            t.witness_signature,
            t.signing_key
        FROM hive.%s_context_data_view c,
        LATERAL ( SELECT hb.num,
            hb.hash,
            hb.prev,
            hb.created_at,
            hb.producer_account_id,
            hb.transaction_merkle_root,
            hb.extensions,
            hb.witness_signature,
            hb.signing_key
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
            hbr.signing_key
           FROM hive.blocks_reversible hbr
           JOIN
           (
             SELECT rb.num, MAX(rb.fork_id) AS max_fork_id
             FROM hive.blocks_reversible rb
             WHERE c.reversible_range AND rb.num > c.irreversible_block AND rb.fork_id <= c.fork_id AND rb.num <= c.current_block_num
             GROUP BY rb.num
           ) visible_blks ON visible_blks.num = hbr.num AND visible_blks.max_fork_id = hbr.fork_id

        ) t;
        ;', _context_name, _context_name
    );
    PERFORM hive.dlog(_context_name, 'Exiting create_blocks_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_blocks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
PERFORM hive.dlog(_context_name, 'Entering create_all_irreversible_blocks_view');
EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_blocks_view
        AS
        SELECT hb.num,
            hb.hash,
            hb.prev,
            hb.created_at,
            hb.producer_account_id,
            hb.transaction_merkle_root,
            hb.extensions,
            hb.witness_signature,
            hb.signing_key
        FROM hive.blocks hb
        ;', _context_name
    );
    PERFORM hive.dlog(_context_name, 'Exiting create_all_irreversible_blocks_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_blocks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
PERFORM hive.dlog(_context_name, 'Entering drop_blocks_view');
EXECUTE format( 'DROP VIEW IF EXISTS hive.%s_blocks_view CASCADE;', _context_name );
PERFORM hive.dlog(_context_name, 'Exiting drop_blocks_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_transactions_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.dlog(_context_name, 'Entering create_transactions_view');
    EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_transactions_view AS
        SELECT t.block_num,
           t.trx_in_block,
           t.trx_hash,
           t.ref_block_num,
           t.ref_block_prefix,
           t.expiration,
           t.signature
        FROM hive.%s_context_data_view c,
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
    , _context_name, _context_name, _context_name
    );
    PERFORM hive.dlog(_context_name, 'Exiting create_transactions_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_transactions_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
PERFORM hive.dlog(_context_name, 'Entering create_all_irreversible_transactions_view');
EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_transactions_view AS
        SELECT ht.block_num,
           ht.trx_in_block,
           ht.trx_hash,
           ht.ref_block_num,
           ht.ref_block_prefix,
           ht.expiration,
           ht.signature
        FROM hive.transactions ht
       ;'
    , _context_name
    );
    PERFORM hive.dlog(_context_name, 'Exiting create_all_irreversible_transactions_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_transactions_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.dlog(_context_name, 'Entering drop_transactions_view');
    EXECUTE format( 'DROP VIEW IF EXISTS hive.%s_transactions_view CASCADE;', _context_name );
    PERFORM hive.dlog(_context_name, 'Exiting drop_transactions_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
PERFORM hive.dlog(_context_name, 'Entering create_operations_view');
EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_operations_view
         AS
         SELECT t.id,
            t.block_num,
            t.trx_in_block,
            t.op_pos,
            t.op_type_id,
            t.timestamp,
            t.body
          FROM hive.%s_context_data_view c,
          LATERAL
          (
            SELECT
              ho.id,
              ho.block_num,
              ho.trx_in_block,
              ho.op_pos,
              ho.op_type_id,
              ho.timestamp,
              ho.body
              FROM hive.operations ho
              WHERE ho.block_num <= c.min_block
            UNION ALL
              SELECT
                o.id,
                o.block_num,
                o.trx_in_block,
                o.op_pos,
                o.op_type_id,
                o.timestamp,
                o.body
              FROM hive.operations_reversible o
              -- Reversible operations view must show ops comming from newest fork (specific to app-context)
              -- and also hide ops present at earlier forks for given block
              JOIN
              (
                SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
                FROM hive.blocks_reversible hbr
                WHERE c.reversible_range AND hbr.num > c.irreversible_block AND hbr.fork_id <= c.fork_id AND hbr.num <= c.current_block_num
                GROUP by hbr.num
              ) visible_ops on visible_ops.num = o.block_num and visible_ops.max_fork_id = o.fork_id
        ) t
        ;', _context_name, _context_name
    );
    PERFORM hive.dlog(_context_name, 'Exiting create_operations_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
PERFORM hive.dlog(_context_name, 'Entering create_operaticreate_all_irreversible_operations_viewons_view');
EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_operations_view
         AS
         SELECT
            ho.id,
            ho.block_num,
            ho.trx_in_block,
            ho.op_pos,
            ho.op_type_id,
            ho.timestamp,
            ho.body
        FROM hive.operations ho
        ;', _context_name
    );
    PERFORM hive.dlog(_context_name, 'Exiting create_operaticreate_all_irreversible_operations_viewons_view');
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.drop_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.dlog(_context_name, 'Entering drop_operations_view');
    EXECUTE format( 'DROP VIEW IF EXISTS hive.%s_operations_view CASCADE;', _context_name );
    PERFORM hive.dlog(_context_name, 'Exiting drop_operations_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_signatures_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
PERFORM hive.dlog(_context_name, 'Entering create_signatures_view');
EXECUTE format(
    'CREATE OR REPLACE VIEW hive.%s_TRANSACTIONS_MULTISIG_VIEW
    AS
    SELECT
          t.trx_hash
        , t.signature
    FROM hive.%s_context_data_view c,
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
        , _context_name, _context_name, _context_name, _context_name
    );
    PERFORM hive.dlog(_context_name, 'Exiting create_signatures_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_signatures_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.dlog(_context_name, 'Entering create_all_irreversible_signatures_view');
EXECUTE format(
    'CREATE OR REPLACE VIEW hive.%s_TRANSACTIONS_MULTISIG_VIEW
    AS
    SELECT
          htm.trx_hash
        , htm.signature
    FROM hive.transactions_multisig htm
    ;'
    , _context_name
    );
    PERFORM hive.dlog(_context_name, 'Exiting create_all_irreversible_signatures_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_signatures_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.dlog(_context_name, 'Entering drop_signatures_view');
    EXECUTE format( 'DROP VIEW IF EXISTS hive.%s_TRANSACTIONS_MULTISIG_VIEW CASCADE;', _context_name );
    PERFORM hive.dlog(_context_name, 'Exiting drop_signatures_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_accounts_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
PERFORM hive.dlog(_context_name, 'Entering create_accounts_view');
EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_accounts_view AS
        SELECT
           t.block_num,
           t.id,
           t.name
        FROM hive.%s_context_data_view c,
        LATERAL
        (
          SELECT ha.block_num,
                 ha.id,
                 ha.name
                FROM hive.accounts ha
                WHERE ha.block_num <= c.min_block
                UNION ALL
                SELECT
                    reversible.block_num,
                    reversible.id,
                    reversible.name
                FROM ( SELECT
                    har.block_num,
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
    , _context_name, _context_name, _context_name
    );
    PERFORM hive.dlog(_context_name, 'Exiting create_accounts_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_accounts_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
PERFORM hive.dlog(_context_name, 'Entering create_all_irreversible_accounts_view');
EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_accounts_view AS
        SELECT
           ha.block_num,
           ha.id,
           ha.name
        FROM hive.accounts ha
    ;', _context_name
    );
    PERFORM hive.dlog(_context_name, 'Exiting create_all_irreversible_accounts_view');
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.drop_accounts_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
PERFORM hive.dlog(_context_name, 'Entering drop_accounts_view');
EXECUTE format( 'DROP VIEW IF EXISTS hive.%s_accounts_view CASCADE;', _context_name );
PERFORM hive.dlog(_context_name, 'Exiting drop_accounts_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_account_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.dlog(_context_name, 'Entering create_account_operations_view');
EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_account_operations_view AS
        SELECT
           t.block_num,
           t.account_id,
           t.account_op_seq_no,
           t.operation_id,
           t.op_type_id
        FROM hive.%s_context_data_view c,
        LATERAL
        (
          SELECT
                 ha.block_num,
                 ha.account_id,
                 ha.account_op_seq_no,
                 ha.operation_id,
                 ha.op_type_id
                FROM hive.account_operations ha
                WHERE ha.block_num <= c.min_block
                UNION ALL
                SELECT
                    reversible.block_num,
                    reversible.account_id,
                    reversible.account_op_seq_no,
                    reversible.operation_id,
                    reversible.op_type_id
                FROM ( SELECT
                    har.block_num,
                    har.account_id,
                    har.account_op_seq_no,
                    har.operation_id,
                    har.op_type_id,
                    har.fork_id
                FROM hive.account_operations_reversible har
                JOIN (
                        SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
                        FROM hive.blocks_reversible hbr
                        WHERE c.reversible_range AND hbr.num > c.irreversible_block AND hbr.fork_id <= c.fork_id AND hbr.num <= c.current_block_num
                        GROUP by hbr.num
                ) as arr ON arr.max_fork_id = har.fork_id AND arr.num = har.block_num
             ) reversible
        ) t
        ;'
    , _context_name, _context_name, _context_name
    );
    PERFORM hive.dlog(_context_name, 'Exiting create_account_operations_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_account_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.dlog(_context_name, 'Entering create_all_irreversible_account_operations_view');
EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_account_operations_view AS
        SELECT
           ha.block_num,
           ha.account_id,
           ha.account_op_seq_no,
           ha.operation_id,
           ha.op_type_id
        FROM hive.account_operations ha
        ;'
    , _context_name
    );
    PERFORM hive.dlog(_context_name, 'Exiting create_all_irreversible_account_operations_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_account_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.dlog(_context_name, 'Entering drop_account_operations_view');
    EXECUTE format( 'DROP VIEW IF EXISTS hive.%s_account_operations_view CASCADE;', _context_name );
    PERFORM hive.dlog(_context_name, 'Exiting drop_account_operations_view');
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.create_applied_hardforks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_applied_hardforks_view AS
        SELECT
           t.hardfork_num,
           t.block_num,
           t.hardfork_vop_id
        FROM hive.%s_context_data_view c,
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
    , _context_name, _context_name, _context_name
    );
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.create_all_irreversible_applied_hardforks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_applied_hardforks_view AS
        SELECT
                 hr.hardfork_num,
                 hr.block_num,
                 hr.hardfork_vop_id
        FROM hive.applied_hardforks hr
        ;'
    , _context_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_applied_hardforks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format( 'DROP VIEW hive.%s_applied_hardforks_view;', _context_name );
END;
$BODY$
;