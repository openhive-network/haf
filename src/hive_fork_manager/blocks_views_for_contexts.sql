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
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.context_data_view AS
        SELECT
        hc.current_block_num,
        hc.irreversible_block,
        hc.fork_id,
        /*
            Definition of `min_block` (from least(current_block_num, irrecersible_block)) has been changed because of creation of gap,
            between app irreversible block and app reversibble blocks which are no longer in hive.reversible blocks,
            because of delay of processing blocks, which can be long enough, that blocks are no longer avaiable in previously mentioned table,
            but are in hafd.blocks.
        */
        LEAST(
              hc.irreversible_block
            , hc.current_block_num
        ) AS min_block,
        hc.current_block_num > hc.irreversible_block AND hc.is_forking AS reversible_range
        FROM hafd.contexts hc
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
    FROM hafd.contexts hc
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
  SELECT c.owner, c.schema INTO __owner_name, __schema FROM hafd.contexts c WHERE c.name = _context_name;

  EXECUTE format('ALTER VIEW %s.%s OWNER TO %s;', __schema, _view_base_name, __owner_name);

END;
$BODY$
;

/*
The horizon of a context's views, read from the context's row in hafd.contexts: any session reading the views
sees the horizon the context's sync loop last committed. SECURITY DEFINER, so that a reader of the views needs no
access to hafd.contexts, as when the views joined `<schema>.context_data_view`.
*/
CREATE OR REPLACE FUNCTION hive.context_view_horizon(
      _context TEXT
    , OUT min_block INTEGER
    , OUT irreversible_block INTEGER
    , OUT current_block_num INTEGER
    , OUT fork_id BIGINT
    , OUT reversible_range BOOLEAN
)
    LANGUAGE sql
    STABLE
    PARALLEL SAFE
    SECURITY DEFINER
    SET search_path = pg_catalog, pg_temp
AS
$BODY$
    -- min_block: a context behind the irreversible block sees the irreversible blocks up to its current block only
    SELECT
          LEAST( hc.irreversible_block, hc.current_block_num )
        , hc.irreversible_block
        , hc.current_block_num
        , hc.fork_id
        , hc.current_block_num > hc.irreversible_block AND hc.is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context
$BODY$
;

/*
A field of hive.context_view_horizon as an uncorrelated subquery, which the planner runs once per query as an InitPlan.
Calling the function directly in a view would run it again on every rescan of a nested loop's inner index scan.
*/
CREATE OR REPLACE FUNCTION hive.context_view_horizon_value( _context_name TEXT, _field TEXT )
    RETURNS TEXT
    LANGUAGE sql
    IMMUTABLE
AS
$BODY$
    SELECT format( '( SELECT h.%I FROM hive.context_view_horizon( %L ) h )', _field, _context_name );
$BODY$
;

/*
The filter of a context view's irreversible rows, _block_num being the SQL of a row's block number.
`<= ANY( ARRAY[ x ] )` means `<= x` and is still an index condition, but the planner does not combine it with a
query's own range on the same column: a range bound it cannot estimate (an InitPlan's value) would make it estimate
the whole range at its 0.5% default.
*/
CREATE OR REPLACE FUNCTION hive.context_view_irreversible_filter( _context_name TEXT, _block_num TEXT )
    RETURNS TEXT
    LANGUAGE sql
    IMMUTABLE
AS
$BODY$
    SELECT format( '%s <= ANY( ARRAY[ %s ] )', _block_num, hive.context_view_horizon_value( _context_name, 'min_block' ) );
$BODY$
;

/*
The filter of a context view's reversible rows, without the guard of hive.context_view_reversible_guard: a row of block
_block_num and fork _fork_id is visible when the block is in the context's reversible range and the fork is the newest
one of the block the context has seen.
*/
CREATE OR REPLACE FUNCTION hive.context_view_reversible_filter( _context_name TEXT, _block_num TEXT, _fork_id TEXT )
    RETURNS TEXT
    LANGUAGE sql
    IMMUTABLE
AS
$BODY$
    SELECT format(
          '%1$s > %3$s AND %1$s <= %4$s AND %2$s = ( SELECT MAX( rb.fork_id ) FROM hafd.blocks_reversible rb WHERE rb.num = %1$s AND rb.fork_id <= %5$s )'
        , _block_num
        , _fork_id
        , hive.context_view_horizon_value( _context_name, 'irreversible_block' )
        , hive.context_view_horizon_value( _context_name, 'current_block_num' )
        , hive.context_view_horizon_value( _context_name, 'fork_id' )
    );
$BODY$
;

/*
Whether a context may see reversible rows at all. Having no columns, it becomes a one-time filter of the plan's
reversible branch, so a context without a reversible range never probes the reversible tables.
*/
CREATE OR REPLACE FUNCTION hive.context_view_reversible_guard( _context_name TEXT )
    RETURNS TEXT
    LANGUAGE sql
    IMMUTABLE
AS
$BODY$
    SELECT hive.context_view_horizon_value( _context_name, 'reversible_range' );
$BODY$
;

/*
The WHERE clause of a forking context's view over `t`, the UNION ALL of an irreversible leg (`t.leg = 0`) and a
reversible leg (`t.leg = 1`, with the row's `t.fork_id`), _block_num being the SQL of a row's block number.
The legs themselves have no WHERE clause: only then does the planner pull them up into an append relation whose
members a join can probe through their indexes. Filtering on the constant `leg` lets it drop, for each leg, the
half of this clause that does not apply to it.
*/
CREATE OR REPLACE FUNCTION hive.context_view_legs_filter( _context_name TEXT, _block_num TEXT )
    RETURNS TEXT
    LANGUAGE sql
    IMMUTABLE
AS
$BODY$
    SELECT format(
          '( t.leg = 0 AND %s ) OR ( t.leg = 1 AND %s AND %s )'
        , hive.context_view_irreversible_filter( _context_name, _block_num )
        , hive.context_view_reversible_guard( _context_name )
        , hive.context_view_reversible_filter( _context_name, _block_num, 't.fork_id' )
    );
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
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    IF __is_forking THEN
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
            FROM (
                SELECT 0 AS leg,
                    hb.num,
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
                    hb.dhf_interval_ledger,
                    NULL::BIGINT AS fork_id
                FROM hafd.blocks hb
                UNION ALL
                SELECT 1 AS leg,
                    hbr.num,
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
                    hbr.dhf_interval_ledger,
                    hbr.fork_id
                FROM hafd.blocks_reversible hbr
            ) t
            WHERE %s
            ;', __schema, hive.context_view_legs_filter( _context_name, 't.num' )
        );
    ELSE
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
                FROM hafd.blocks hb
                WHERE %s
            ;', __schema, hive.context_view_irreversible_filter( _context_name, 'hb.num' )
        );
    END IF;

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
FROM hafd.contexts hc
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
        FROM hafd.blocks hb
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
FROM hafd.contexts hc
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
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    IF __is_forking THEN
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.transactions_view AS
            SELECT t.block_num,
               t.trx_in_block,
               t.trx_hash,
               t.ref_block_num,
               t.ref_block_prefix,
               t.expiration,
               t.signature,
               t.rc_cost
            FROM (
                SELECT 0 AS leg,
                    ht.block_num,
                    ht.trx_in_block,
                    ht.trx_hash,
                    ht.ref_block_num,
                    ht.ref_block_prefix,
                    ht.expiration,
                    ht.signature,
                    ht.rc_cost,
                    NULL::BIGINT AS fork_id
                FROM hafd.transactions ht
                UNION ALL
                SELECT 1 AS leg,
                    htr.block_num,
                    htr.trx_in_block,
                    htr.trx_hash,
                    htr.ref_block_num,
                    htr.ref_block_prefix,
                    htr.expiration,
                    htr.signature,
                    htr.rc_cost,
                    htr.fork_id
                FROM hafd.transactions_reversible htr
            ) t
            WHERE %s
            ;'
        , __schema, hive.context_view_legs_filter( _context_name, 't.block_num' )
        );
    ELSE
        EXECUTE format(
                'CREATE OR REPLACE VIEW %s.transactions_view AS
                SELECT ht.block_num,
                   ht.trx_in_block,
                   ht.trx_hash,
                   ht.ref_block_num,
                   ht.ref_block_prefix,
                   ht.expiration,
                   ht.signature,
                   ht.rc_cost
                FROM hafd.transactions ht
                WHERE %s
                ;'
            , __schema, hive.context_view_irreversible_filter( _context_name, 'ht.block_num' )
            );
    END IF;
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
FROM hafd.contexts hc
WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.transactions_view AS
        SELECT ht.block_num,
           ht.trx_in_block,
           ht.trx_hash,
           ht.ref_block_num,
           ht.ref_block_prefix,
           ht.expiration,
           ht.signature,
           ht.rc_cost
        FROM hafd.transactions ht
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
FROM hafd.contexts hc
WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.transactions_view CASCADE;', __schema );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_operations_view_extended( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
        WHERE hc.name = _context_name;

    IF __is_forking THEN
        -- A leg joined with its blocks would not be a single table, which the planner cannot pull up into an append
        -- relation, so each leg reads the timestamp of an operation's block in a subquery.
        EXECUTE format(
                'CREATE OR REPLACE VIEW %s.operations_view_extended
                 AS
                 SELECT t.id,
                    hafd.operation_id_to_block_num( t.id ) as block_num,
                    t.trx_in_block,
                    t.op_pos,
                    t.op_type_id,
                    t.timestamp,
                    t.body_value,
                    jsonb_build_object(''type'', replace(ot.name, ''hive::protocol::'', ''''), ''value'', t.body_value) AS body,
                    t.custom_json_type_id
                  FROM (
                    SELECT 0 AS leg,
                      ho.id,
                      ho.trx_in_block,
                      ho.op_pos,
                      ho.op_type_id,
                      ( SELECT b.created_at FROM hafd.blocks b WHERE b.num = hafd.operation_id_to_block_num( ho.id ) ) AS timestamp,
                      ho.body_value,
                      ho.custom_json_type_id,
                      NULL::BIGINT AS fork_id
                    FROM hafd.operations ho
                    UNION ALL
                    SELECT 1 AS leg,
                      o.id,
                      o.trx_in_block,
                      o.op_pos,
                      o.op_type_id,
                      ( SELECT b.created_at FROM hafd.blocks_reversible b WHERE b.num = hafd.operation_id_to_block_num( o.id ) AND b.fork_id = o.fork_id ) AS timestamp,
                      o.body_value,
                      o.custom_json_type_id,
                      o.fork_id
                    FROM hafd.operations_reversible o
                ) t
                JOIN hafd.operation_types ot ON ot.id = t.op_type_id
                WHERE %s
                ;', __schema, hive.context_view_legs_filter( _context_name, 'hafd.operation_id_to_block_num( t.id )' )
            );
        ELSE
            EXECUTE format(
                    'CREATE OR REPLACE VIEW %s.operations_view_extended
                     AS
                     SELECT ho.id,
                        hafd.operation_id_to_block_num( ho.id ) as block_num,
                        ho.trx_in_block,
                        ho.op_pos,
                        ho.op_type_id,
                        b.created_at timestamp,
                        ho.body_value,
                        jsonb_build_object(''type'', replace(ot.name, ''hive::protocol::'', ''''), ''value'', ho.body_value) AS body,
                        ho.custom_json_type_id
                    FROM hafd.operations ho
                    JOIN hafd.blocks b ON b.num = hafd.operation_id_to_block_num(ho.id)
                    JOIN hafd.operation_types ot ON ot.id = ho.op_type_id
                    WHERE %s
                    ;', __schema, hive.context_view_irreversible_filter( _context_name, 'hafd.operation_id_to_block_num( ho.id )' )
                    );
        END IF;
    PERFORM hive.adjust_view_ownership(_context_name, 'operations_view_extended');
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
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    IF __is_forking THEN
        EXECUTE format(
                'CREATE OR REPLACE VIEW %s.operations_view
                 AS
                 SELECT t.id,
                    hafd.operation_id_to_block_num( t.id ) as block_num,
                    t.trx_in_block,
                    t.op_pos,
                    t.op_type_id,
                    t.body_value,
                    jsonb_build_object(''type'', replace(ot.name, ''hive::protocol::'', ''''), ''value'', t.body_value) AS body,
                    t.custom_json_type_id
                  FROM (
                    SELECT 0 AS leg,
                      ho.id,
                      ho.trx_in_block,
                      ho.op_pos,
                      ho.op_type_id,
                      ho.body_value,
                      ho.custom_json_type_id,
                      NULL::BIGINT AS fork_id
                    FROM hafd.operations ho
                    UNION ALL
                    SELECT 1 AS leg,
                      o.id,
                      o.trx_in_block,
                      o.op_pos,
                      o.op_type_id,
                      o.body_value,
                      o.custom_json_type_id,
                      o.fork_id
                    FROM hafd.operations_reversible o
                ) t
                JOIN hafd.operation_types ot ON ot.id = t.op_type_id
                WHERE %s
                ;', __schema, hive.context_view_legs_filter( _context_name, 'hafd.operation_id_to_block_num( t.id )' )
            );
    ELSE
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.operations_view
                 AS
                 SELECT ho.id,
                    hafd.operation_id_to_block_num( ho.id ) as block_num,
                    ho.trx_in_block,
                    ho.op_pos,
                    ho.op_type_id,
                    ho.body_value,
                    jsonb_build_object(''type'', replace(ot.name, ''hive::protocol::'', ''''), ''value'', ho.body_value) AS body,
                    ho.custom_json_type_id
                  FROM hafd.operations ho
                  JOIN hafd.operation_types ot ON ot.id = ho.op_type_id
                  WHERE %s
                ;', __schema, hive.context_view_irreversible_filter( _context_name, 'hafd.operation_id_to_block_num( ho.id )' )
        );
    END IF;
    PERFORM hive.adjust_view_ownership(_context_name, 'operations_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_operations_view_extended( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view_extended
         AS
         SELECT
            ho.id,
            hafd.operation_id_to_block_num( ho.id ) as block_num,
            ho.trx_in_block,
            ho.op_pos,
            ho.op_type_id,
            b.created_at timestamp,
            ho.body_value,
            jsonb_build_object(''type'', replace(ot.name, ''hive::protocol::'', ''''), ''value'', ho.body_value) AS body,
            ho.custom_json_type_id
        FROM hafd.operations ho
        JOIN hafd.blocks b ON b.num = hafd.operation_id_to_block_num(ho.id)
        JOIN hafd.operation_types ot ON ot.id = ho.op_type_id
        ;', __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'operations_view_extended');
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
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view
         AS
         SELECT
            ho.id,
            hafd.operation_id_to_block_num( ho.id ) as block_num,
            ho.trx_in_block,
            ho.op_pos,
            ho.op_type_id,
            ho.body_value,
            jsonb_build_object(''type'', replace(ot.name, ''hive::protocol::'', ''''), ''value'', ho.body_value) AS body,
            ho.custom_json_type_id
        FROM hafd.operations ho
        JOIN hafd.operation_types ot ON ot.id = ho.op_type_id
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
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.operations_view CASCADE;', __schema );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_operations_view_extended( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.operations_view_extended CASCADE;', __schema );
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
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    IF __is_forking THEN
        -- A signature has no block number of its own: its transaction's block is checked in a subquery, which keeps
        -- each leg a single table.
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW
            AS
            SELECT
                  t.trx_hash
                , t.signature
            FROM (
                SELECT
                      0 AS leg
                    , htm.trx_hash
                    , htm.signature
                    , NULL::BIGINT AS fork_id
                FROM hafd.transactions_multisig htm
                UNION ALL
                SELECT
                      1 AS leg
                    , htmr.trx_hash
                    , htmr.signature
                    , htmr.fork_id
                FROM hafd.transactions_multisig_reversible htmr
            ) t
            WHERE ( t.leg = 0 AND EXISTS ( SELECT 1 FROM hafd.transactions ht WHERE ht.trx_hash = t.trx_hash AND %s ) )
               OR ( t.leg = 1 AND %s AND EXISTS (
                        SELECT 1 FROM hafd.transactions_reversible htr
                        WHERE htr.trx_hash = t.trx_hash AND htr.fork_id = t.fork_id AND %s ) )
            ;'
            , __schema
            , hive.context_view_irreversible_filter( _context_name, 'ht.block_num' )
            , hive.context_view_reversible_guard( _context_name )
            , hive.context_view_reversible_filter( _context_name, 'htr.block_num', 'htr.fork_id' )
            );
    ELSE
        EXECUTE format(
                'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW
                AS
                SELECT
                      htm.trx_hash
                    , htm.signature
                FROM hafd.transactions_multisig htm
                JOIN hafd.transactions ht ON ht.trx_hash = htm.trx_hash
                WHERE %s
            ;'
            , __schema, hive.context_view_irreversible_filter( _context_name, 'ht.block_num' )
        );
    END IF;
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
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
    'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW
    AS
    SELECT
          htm.trx_hash
        , htm.signature
    FROM hafd.transactions_multisig htm
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
    FROM hafd.contexts hc
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
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    IF __is_forking THEN
        EXECUTE format(
                'CREATE OR REPLACE VIEW %s.accounts_view AS
                SELECT
                   t.id,
                   t.name
                FROM (
                    SELECT 0 AS leg,
                        ha.id,
                        ha.name,
                        COALESCE( ha.block_num, 1 ) AS block_num,
                        NULL::BIGINT AS fork_id
                    FROM hafd.accounts ha
                    UNION ALL
                    SELECT 1 AS leg,
                        har.id,
                        har.name,
                        har.block_num,
                        har.fork_id
                    FROM hafd.accounts_reversible har
                ) t
                WHERE %s
                ;'
            , __schema, hive.context_view_legs_filter( _context_name, 't.block_num' )
            );
    ELSE
        EXECUTE format(
                'CREATE OR REPLACE VIEW %s.accounts_view AS
                SELECT
                   ha.id,
                   ha.name
                FROM hafd.accounts ha
                WHERE %s
                ;'
            , __schema, hive.context_view_irreversible_filter( _context_name, 'COALESCE( ha.block_num, 1 )' )
        );
    END IF;
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
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.accounts_view AS
        SELECT
           ha.id,
           ha.name
        FROM hafd.accounts ha
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
    FROM hafd.contexts hc
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
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    IF __is_forking THEN
        EXECUTE format(
                'CREATE OR REPLACE VIEW %s.account_operations_view AS
                SELECT
                   hafd.operation_id_to_block_num( t.operation_id ) as block_num,
                   t.account_id,
                   t.transacting_account_id,
                   t.account_op_seq_no,
                   t.operation_id,
                   t.op_type_id
                FROM (
                    SELECT 0 AS leg,
                        ha.account_id,
                        ha.transacting_account_id,
                        ha.account_op_seq_no,
                        ha.operation_id,
                        ha.op_type_id,
                        NULL::BIGINT AS fork_id
                    FROM hafd.account_operations ha
                    UNION ALL
                    SELECT 1 AS leg,
                        har.account_id,
                        har.transacting_account_id,
                        har.account_op_seq_no,
                        har.operation_id,
                        har.op_type_id,
                        har.fork_id
                    FROM hafd.account_operations_reversible har
                ) t
                WHERE %s
                ;'
            , __schema, hive.context_view_legs_filter( _context_name, 'hafd.operation_id_to_block_num( t.operation_id )' )
            );
    ELSE
        EXECUTE format(
                'CREATE OR REPLACE VIEW %s.account_operations_view AS
                SELECT
                   hafd.operation_id_to_block_num( ha.operation_id ) as block_num,
                   ha.account_id,
                   ha.transacting_account_id,
                   ha.account_op_seq_no,
                   ha.operation_id,
                   ha.op_type_id
                FROM hafd.account_operations ha
                WHERE %s
                ;'
            , __schema, hive.context_view_irreversible_filter( _context_name, 'hafd.operation_id_to_block_num( ha.operation_id )' )
            );
    END IF;
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
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.account_operations_view AS
        SELECT
           hafd.operation_id_to_block_num( ha.operation_id ) as block_num,
           ha.account_id,
           ha.transacting_account_id,
           ha.account_op_seq_no,
           ha.operation_id,
           ha.op_type_id
        FROM hafd.account_operations ha
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
    FROM hafd.contexts hc
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
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    IF __is_forking THEN
        EXECUTE format(
                'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
                SELECT
                   t.hardfork_num,
                   t.block_num,
                   t.hardfork_vop_id
                FROM (
                    SELECT 0 AS leg,
                        hr.hardfork_num,
                        hr.block_num,
                        hr.hardfork_vop_id,
                        NULL::BIGINT AS fork_id
                    FROM hafd.applied_hardforks hr
                    UNION ALL
                    SELECT 1 AS leg,
                        hjr.hardfork_num,
                        hjr.block_num,
                        hjr.hardfork_vop_id,
                        hjr.fork_id
                    FROM hafd.applied_hardforks_reversible hjr
                ) t
                WHERE %s
                ;'
            , __schema, hive.context_view_legs_filter( _context_name, 't.block_num' )
            );
    ELSE
        EXECUTE format(
                'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
                SELECT
                   hr.hardfork_num,
                   hr.block_num,
                   hr.hardfork_vop_id
                FROM hafd.applied_hardforks hr
                WHERE %s
                ;'
            , __schema, hive.context_view_irreversible_filter( _context_name, 'hr.block_num' )
        );
    END IF;
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
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
        SELECT
                 hr.hardfork_num,
                 hr.block_num,
                 hr.hardfork_vop_id
        FROM hafd.applied_hardforks hr
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
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.applied_hardforks_view;', __schema );
END;
$BODY$
;
