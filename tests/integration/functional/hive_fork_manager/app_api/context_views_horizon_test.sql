-- Every view of a forking and of a non-forking context returns the rows the definitions the views had when they read
-- their horizon from `<schema>.context_data_view` return, in every state of the horizon: a reversible range, a fork
-- switch, no reversible range, a context behind its irreversible block. The rows are also read as a role which may
-- only read the views, and through a cached generic plan while the horizon moves. All of it in both modes of
-- hive.set_context_view_horizon_mode: 'initplan', which generates the views as they were before the mode existed,
-- and 'c'.

-- The rows `_view` of `_context` must show: the definitions of the views from before they read hive.context_view_horizon.
CREATE OR REPLACE FUNCTION expected_view_rows( _context TEXT, _view TEXT )
    RETURNS TEXT
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
DECLARE
    __horizon TEXT := format( $$
        WITH c AS (
            SELECT LEAST( hc.irreversible_block, hc.current_block_num ) AS min_block
            FROM hafd.contexts hc WHERE hc.name = %1$L
        ), visible AS (
            SELECT rb.num, MAX( rb.fork_id ) AS fork_id
            FROM hafd.blocks_reversible rb
            JOIN hafd.contexts hc ON hc.name = %1$L
            WHERE hc.is_forking AND hc.current_block_num > hc.irreversible_block
              AND rb.num > hc.irreversible_block AND rb.num <= hc.current_block_num AND rb.fork_id <= hc.fork_id
            GROUP BY rb.num
        ) $$, _context );
BEGIN
    RETURN __horizon || CASE _view
        WHEN 'blocks_view' THEN $$
            SELECT hb.* FROM hafd.blocks hb, c WHERE hb.num <= c.min_block
            UNION ALL
            SELECT hbr.num, hbr.hash, hbr.prev, hbr.created_at, hbr.producer_account_id, hbr.transaction_merkle_root, hbr.extensions,
                   hbr.witness_signature, hbr.signing_key, hbr.hbd_interest_rate, hbr.total_vesting_fund_hive, hbr.total_vesting_shares,
                   hbr.total_reward_fund_hive, hbr.virtual_supply, hbr.current_supply, hbr.current_hbd_supply, hbr.dhf_interval_ledger
            FROM hafd.blocks_reversible hbr JOIN visible v ON v.num = hbr.num AND v.fork_id = hbr.fork_id $$
        WHEN 'transactions_view' THEN $$
            SELECT ht.* FROM hafd.transactions ht, c WHERE ht.block_num <= c.min_block
            UNION ALL
            SELECT htr.block_num, htr.trx_in_block, htr.trx_hash, htr.ref_block_num, htr.ref_block_prefix, htr.expiration, htr.signature, htr.rc_cost
            FROM hafd.transactions_reversible htr JOIN visible v ON v.num = htr.block_num AND v.fork_id = htr.fork_id $$
        WHEN 'operations_view' THEN $$
            SELECT o.id, hafd.operation_id_to_block_num( o.id ), o.trx_in_block, o.op_pos, o.op_type_id, o.body_value,
                   jsonb_build_object( 'type', replace( ot.name, 'hive::protocol::', '' ), 'value', o.body_value ), o.custom_json_type_id
            FROM (
                SELECT ho.id, ho.trx_in_block, ho.op_pos, ho.op_type_id, ho.body_value, ho.custom_json_type_id
                FROM hafd.operations ho, c WHERE hafd.operation_id_to_block_num( ho.id ) <= c.min_block
                UNION ALL
                SELECT hor.id, hor.trx_in_block, hor.op_pos, hor.op_type_id, hor.body_value, hor.custom_json_type_id
                FROM hafd.operations_reversible hor JOIN visible v ON v.num = hafd.operation_id_to_block_num( hor.id ) AND v.fork_id = hor.fork_id
            ) o JOIN hafd.operation_types ot ON ot.id = o.op_type_id $$
        -- the timestamp of an operation is the one of its block in the same fork
        WHEN 'operations_view_extended' THEN $$
            SELECT o.id, hafd.operation_id_to_block_num( o.id ), o.trx_in_block, o.op_pos, o.op_type_id, o.created_at, o.body_value,
                   jsonb_build_object( 'type', replace( ot.name, 'hive::protocol::', '' ), 'value', o.body_value ), o.custom_json_type_id
            FROM (
                SELECT ho.id, ho.trx_in_block, ho.op_pos, ho.op_type_id, b.created_at, ho.body_value, ho.custom_json_type_id
                FROM hafd.operations ho JOIN hafd.blocks b ON b.num = hafd.operation_id_to_block_num( ho.id ), c
                WHERE hafd.operation_id_to_block_num( ho.id ) <= c.min_block
                UNION ALL
                SELECT hor.id, hor.trx_in_block, hor.op_pos, hor.op_type_id, br.created_at, hor.body_value, hor.custom_json_type_id
                FROM hafd.operations_reversible hor
                JOIN visible v ON v.num = hafd.operation_id_to_block_num( hor.id ) AND v.fork_id = hor.fork_id
                JOIN hafd.blocks_reversible br ON br.num = v.num AND br.fork_id = v.fork_id
            ) o JOIN hafd.operation_types ot ON ot.id = o.op_type_id $$
        WHEN 'transactions_multisig_view' THEN $$
            SELECT htm.trx_hash, htm.signature
            FROM hafd.transactions_multisig htm JOIN hafd.transactions ht ON ht.trx_hash = htm.trx_hash, c
            WHERE ht.block_num <= c.min_block
            UNION ALL
            SELECT htmr.trx_hash, htmr.signature
            FROM hafd.transactions_multisig_reversible htmr
            JOIN hafd.transactions_reversible htr ON htr.trx_hash = htmr.trx_hash AND htr.fork_id = htmr.fork_id
            JOIN visible v ON v.num = htr.block_num AND v.fork_id = htr.fork_id $$
        WHEN 'accounts_view' THEN $$
            SELECT ha.id, ha.name FROM hafd.accounts ha, c WHERE COALESCE( ha.block_num, 1 ) <= c.min_block
            UNION ALL
            SELECT har.id, har.name FROM hafd.accounts_reversible har JOIN visible v ON v.num = har.block_num AND v.fork_id = har.fork_id $$
        WHEN 'account_operations_view' THEN $$
            SELECT hafd.operation_id_to_block_num( hao.operation_id ), hao.account_id, hao.transacting_account_id, hao.account_op_seq_no, hao.operation_id, hao.op_type_id
            FROM hafd.account_operations hao, c WHERE hafd.operation_id_to_block_num( hao.operation_id ) <= c.min_block
            UNION ALL
            SELECT hafd.operation_id_to_block_num( haor.operation_id ), haor.account_id, haor.transacting_account_id, haor.account_op_seq_no, haor.operation_id, haor.op_type_id
            FROM hafd.account_operations_reversible haor
            JOIN visible v ON v.num = hafd.operation_id_to_block_num( haor.operation_id ) AND v.fork_id = haor.fork_id $$
        WHEN 'applied_hardforks_view' THEN $$
            SELECT hah.hardfork_num, hah.block_num, hah.hardfork_vop_id FROM hafd.applied_hardforks hah, c WHERE hah.block_num <= c.min_block
            UNION ALL
            SELECT hahr.hardfork_num, hahr.block_num, hahr.hardfork_vop_id
            FROM hafd.applied_hardforks_reversible hahr JOIN visible v ON v.num = hahr.block_num AND v.fork_id = hahr.fork_id $$
    END;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION context_view_names()
    RETURNS SETOF TEXT
    LANGUAGE sql
    IMMUTABLE
AS
$BODY$
    VALUES ( 'blocks_view' ), ( 'transactions_view' ), ( 'operations_view' ), ( 'operations_view_extended' ),
           ( 'transactions_multisig_view' ), ( 'accounts_view' ), ( 'account_operations_view' ), ( 'applied_hardforks_view' );
$BODY$
;

-- Asserts that every view of _context returns its expected rows, as many times each, and returns how many rows they hold.
CREATE OR REPLACE FUNCTION assert_context_views( _context TEXT, _state TEXT )
    RETURNS BIGINT
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT := ( SELECT hc.schema FROM hafd.contexts hc WHERE hc.name = _context );
    __view TEXT;
    __differs BOOLEAN;
    __rows BIGINT;
    __all_rows BIGINT := 0;
BEGIN
    FOR __view IN SELECT * FROM context_view_names() LOOP
        EXECUTE format( 'SELECT EXISTS ( ( TABLE %1$s EXCEPT ALL ( %2$s ) ) UNION ALL ( ( %2$s ) EXCEPT ALL TABLE %1$s ) ), ( SELECT count(*) FROM %1$s )'
            , format( '%I.%I', __schema, __view ), expected_view_rows( _context, __view ) )
        INTO __differs, __rows;
        ASSERT NOT __differs, format( '%s.%s differs from its expected rows when %s', __schema, __view, _state );
        __all_rows := __all_rows + __rows;
    END LOOP;
    RETURN __all_rows;
END;
$BODY$
;

-- Asserts that a forking context's operations_view_extended joins the blocks of its operations, instead of reading the
-- timestamp in a subquery run for every operation, and that it reads no reversible operation when _reversible is false.
CREATE OR REPLACE FUNCTION assert_operations_view_extended_plan( _schema TEXT, _reversible BOOLEAN, _state TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __plan JSONB;
BEGIN
    EXECUTE format( 'EXPLAIN ( ANALYZE, FORMAT JSON ) SELECT count( t.timestamp ) FROM %I.operations_view_extended t', _schema ) INTO __plan;
    ASSERT NOT jsonb_path_exists( __plan, 'strict $.** ? ( @."Parent Relationship" == "SubPlan" ).** ? ( @."Relation Name" == "blocks" )' )
        , format( '%s.operations_view_extended reads hafd.blocks in a subplan when %s: %s', _schema, _state, __plan );
    ASSERT jsonb_path_exists( __plan, 'strict $.** ? ( @."Relation Name" == "operations_reversible" )' )
        , format( '%s.operations_view_extended has no reversible leg when %s: %s', _schema, _state, __plan );
    IF _reversible THEN
        ASSERT jsonb_array_length( jsonb_path_query_array( __plan, 'strict $.** ? ( @."Relation Name" == "blocks_reversible" )' ) )
            > jsonb_array_length( jsonb_path_query_array( __plan, 'strict $.** ? ( @."Parent Relationship" == "SubPlan" ).** ? ( @."Relation Name" == "blocks_reversible" )' ) )
            , format( '%s.operations_view_extended does not join hafd.blocks_reversible when %s: %s', _schema, _state, __plan );
    ELSE
        ASSERT NOT jsonb_path_exists( __plan, 'strict $.** ? ( @."Relation Name" == "operations_reversible" && @."Actual Loops" > 0 )' )
            , format( '%s.operations_view_extended reads reversible operations when %s: %s', _schema, _state, __plan );
    END IF;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.app_create_context( _name => 'context', _schema => 'a' );
    CREATE SCHEMA b;
    PERFORM hive.app_create_context( _name => 'context_nf', _schema => 'b', _is_forking => FALSE );

    INSERT INTO hafd.operation_types
    VALUES ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hafd.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES ( 5, 'initminer', NULL )
         , ( 100, 'alice1', 1 )
         , ( 200, 'alice2', 2 )
         , ( 300, 'alice3', 3 )
         , ( 400, 'alice4', 4 )
    ;

    INSERT INTO hafd.transactions
    VALUES
           ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF', NULL )
         , ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF', NULL )
         , ( 3, 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF', NULL )
         , ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF', NULL )
         , ( 5, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF', 50 )
    ;

    INSERT INTO hafd.transactions_multisig
    VALUES
           ( '\xDEED10', '\xBAAD10' )
         , ( '\xDEED20', '\xBAAD20' )
         , ( '\xDEED30', '\xBAAD30' )
         , ( '\xDEED40', '\xBAAD40' )
         , ( '\xDEED50', '\xBAAD50' )
    ;

    INSERT INTO hafd.operations( id, trx_in_block, op_type_id, op_pos, body_value )
    VALUES
          ( hafd.operation_id(1, 0), 0, 1, 0, '{"message":"ZERO OPERATION"}'::jsonb )
        , ( hafd.operation_id(2, 0), 0, 1, 0, '{"message":"ONE OPERATION"}'::jsonb )
        , ( hafd.operation_id(3, 0), 0, 1, 0, '{"message":"TWO OPERATION"}'::jsonb )
        , ( hafd.operation_id(4, 0), 0, 1, 0, '{"message":"THREE OPERATION"}'::jsonb )
        , ( hafd.operation_id(5, 0), 0, 1, 0, '{"message":"FIVE OPERATION"}'::jsonb )
    ;

    INSERT INTO hafd.account_operations( account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id )
    VALUES
           ( 100, 100, 1, hafd.operation_id(1, 0), 1 )
         , ( 100, 100, 2, hafd.operation_id(2, 0), 1 )
         , ( 200, 200, 1, hafd.operation_id(2, 0), 1 )
         , ( 300, 300, 1, hafd.operation_id(3, 0), 1 )
         , ( 400, 400, 1, hafd.operation_id(4, 0), 1 )
    ;

    INSERT INTO hafd.applied_hardforks
    VALUES
           ( 1, 1, hafd.operation_id(1, 0) )
         , ( 2, 2, hafd.operation_id(2, 0) )
         , ( 3, 3, hafd.operation_id(3, 0) )
         , ( 4, 4, hafd.operation_id(4, 0) )
         , ( 5, 5, hafd.operation_id(5, 0) )
    ;

    -- block 7 is in forks 1 and 2, blocks 8 and 9 in forks 2 and 3, block 10 in forks 1 and 3
    INSERT INTO hafd.blocks_reversible
    VALUES
           ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD71', '\xCAFE71', '2016-06-22 19:10:37-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 10, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:41-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD72', '\xCAFE72', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD82', '\xCAFE82', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 9, '\xBADD92', '\xCAFE92', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD83', '\xCAFE83', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 9, '\xBADD93', '\xCAFE93', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 10, '\xBADD13', '\xCAFE13', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
    ;

    INSERT INTO hafd.transactions_reversible
    VALUES
       ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF', NULL, 1 )
     , ( 5, 0::SMALLINT, '\xDEED55', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF', 50, 1 )
     , ( 6, 0::SMALLINT, '\xDEED60', 101, 100, '2016-06-22 19:10:26-07'::timestamp, '\xBEEF', 60, 1 )
     , ( 7, 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:37-07'::timestamp, '\xBEEF', 70, 1 )
     , ( 10, 0::SMALLINT, '\xDEED11', 101, 100, '2016-06-22 19:10:41-07'::timestamp, '\xBEEF', 100, 1 )
     , ( 7, 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF', 70, 2 )
     , ( 8, 0::SMALLINT, '\xDEED80', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF', 80, 2 )
     , ( 9, 0::SMALLINT, '\xDEED90', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF', 90, 2 )
     , ( 8, 0::SMALLINT, '\xDEED88', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF', 80, 3 )
     , ( 9, 0::SMALLINT, '\xDEED99', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF', 90, 3 )
     , ( 10, 0::SMALLINT, '\xDEED1102', 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF', 100, 3 )
    ;

    INSERT INTO hafd.transactions_multisig_reversible
    VALUES
       ( '\xDEED40', '\xBEEF40', 1 )
     , ( '\xDEED55', '\xBEEF55', 1 )
     , ( '\xDEED60', '\xBEEF61', 1 )
     , ( '\xDEED70', '\xBEEF7110', 1 )
     , ( '\xDEED70', '\xBEEF7120', 1 )
     , ( '\xDEED11', '\xBEEF7140', 1 )
     , ( '\xDEED70', '\xBEEF72', 2 )
     , ( '\xDEED70', '\xBEEF73', 2 )
     , ( '\xDEED80', '\xBEEF82', 2 )
     , ( '\xDEED90', '\xBEEF92', 2 )
     , ( '\xDEED88', '\xBEEF83', 3 )
     , ( '\xDEED99', '\xBEEF93', 3 )
     , ( '\xDEED1102', '\xBEEF13', 3 )
    ;

    INSERT INTO hafd.operations_reversible( id, trx_in_block, op_type_id, op_pos, body_value, fork_id )
    VALUES
           ( hafd.operation_id(4, 0), 0, 1, 0, '{"message":"THREE OPERATION"}'::jsonb, 1 )
         , ( hafd.operation_id(5, 0), 0, 1, 0, '{"message":"FIVEFIVE OPERATION"}'::jsonb, 1 )
         , ( hafd.operation_id(6, 0), 0, 1, 0, '{"message":"SIX OPERATION"}'::jsonb, 1 )
         , ( hafd.operation_id(7, 0), 0, 1, 0, '{"message":"SEVEN0 OPERATION"}'::jsonb, 1 )
         , ( hafd.operation_id(7, 1), 0, 1, 1, '{"message":"SEVEN01 OPERATION"}'::jsonb, 1 )
         , ( hafd.operation_id(7, 2), 0, 1, 2, '{"message":"SEVEN02 OPERATION"}'::jsonb, 1 )
         , ( hafd.operation_id(10, 0), 0, 1, 0, '{"message":"TEN1 OPERATION"}'::jsonb, 1 )
         , ( hafd.operation_id(7, 0), 0, 1, 0, '{"message":"SEVEN2 OPERATION"}'::jsonb, 2 )
         , ( hafd.operation_id(7, 1), 0, 1, 1, '{"message":"SEVEN21 OPERATION"}'::jsonb, 2 )
         , ( hafd.operation_id(8, 0), 0, 1, 0, '{"message":"EIGHT2 OPERATION"}'::jsonb, 2 )
         , ( hafd.operation_id(9, 0), 0, 1, 0, '{"message":"NINE2 OPERATION"}'::jsonb, 2 )
         , ( hafd.operation_id(8, 0), 0, 1, 0, '{"message":"EIGHT3 OPERATION"}'::jsonb, 3 )
         , ( hafd.operation_id(9, 0), 0, 1, 0, '{"message":"NINE3 OPERATION"}'::jsonb, 3 )
         , ( hafd.operation_id(10, 0), 0, 1, 0, '{"message":"TEN3 OPERATION"}'::jsonb, 3 )
    ;

    INSERT INTO hafd.accounts_reversible
    VALUES
           ( 400, 'alice41', 4, 1 )
         , ( 500, 'alice51', 5, 1 )
         , ( 600, 'alice61', 6, 1 )
         , ( 700, 'alice71', 7, 1 )
         , ( 800, 'bob71', 7, 1 )
         , ( 700, 'alice72', 7, 2 )
         , ( 800, 'bob72', 7, 2 )
         , ( 900, 'alice82', 8, 2 )
         , ( 1000, 'alice92', 9, 2 )
         , ( 900, 'alice83', 8, 3 )
         , ( 1000, 'alice93', 9, 3 )
         , ( 1100, 'alice103', 10, 3 )
    ;

    INSERT INTO hafd.account_operations_reversible
    VALUES
           ( 400, 400, 1, hafd.operation_id(4, 0), 1, 1 )
         , ( 500, 500, 1, hafd.operation_id(5, 0), 1, 1 )
         , ( 600, 600, 1, hafd.operation_id(6, 0), 1, 1 )
         , ( 700, 700, 1, hafd.operation_id(7, 0), 1, 1 )
         , ( 800, 800, 1, hafd.operation_id(7, 1), 1, 1 )
         , ( 900, 900, 1, hafd.operation_id(7, 2), 1, 1 )
         , ( 700, 700, 2, hafd.operation_id(7, 0), 1, 2 )
         , ( 800, 800, 2, hafd.operation_id(7, 1), 1, 2 )
         , ( 900, 900, 2, hafd.operation_id(8, 0), 1, 2 )
         , ( 1000, 1000, 2, hafd.operation_id(9, 0), 1, 2 )
         , ( 900, 900, 3, hafd.operation_id(9, 0), 1, 3 )
         , ( 1100, 1100, 3, hafd.operation_id(10, 0), 1, 3 )
    ;

    INSERT INTO hafd.applied_hardforks_reversible
    VALUES
           ( 4, 4, hafd.operation_id(4, 0), 1 )
         , ( 5, 5, hafd.operation_id(5, 0), 1 )
         , ( 6, 6, hafd.operation_id(6, 0), 1 )
         , ( 7, 7, hafd.operation_id(7, 0), 1 )
         , ( 8, 7, hafd.operation_id(7, 1), 1 )
         , ( 7, 7, hafd.operation_id(7, 0), 2 )
         , ( 8, 7, hafd.operation_id(7, 1), 2 )
         , ( 9, 8, hafd.operation_id(8, 0), 2 )
         , ( 10, 9, hafd.operation_id(9, 0), 2 )
         , ( 8, 8, hafd.operation_id(8, 0), 3 )
         , ( 9, 9, hafd.operation_id(9, 0), 3 )
         , ( 10, 10, hafd.operation_id(10, 0), 3 )
    ;

    IF NOT EXISTS ( SELECT 1 FROM pg_roles WHERE rolname = 'context_views_reader' ) THEN
        CREATE ROLE context_views_reader;
    END IF;
    GRANT USAGE ON SCHEMA a TO context_views_reader;
    GRANT SELECT ON ALL TABLES IN SCHEMA a TO context_views_reader;

    CREATE TABLE default_view_definitions AS SELECT * FROM context_view_definitions();
END;
$BODY$
;

-- The definitions of the views of both contexts.
CREATE OR REPLACE FUNCTION context_view_definitions()
    RETURNS TABLE( view_name TEXT, definition TEXT )
    LANGUAGE sql
    STABLE
AS
$BODY$
    SELECT format( '%I.%I', n.nspname, c.relname ), pg_get_viewdef( c.oid )
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ( 'a', 'b' ) AND c.relname IN ( SELECT * FROM context_view_names() )
    ORDER BY 1;
$BODY$
;

-- Asserts that the views of both contexts are defined as when the contexts were created, in the default mode.
CREATE OR REPLACE FUNCTION assert_default_view_definitions( _state TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __differing TEXT;
BEGIN
    SELECT string_agg( COALESCE( d.view_name, c.view_name ), ', ' ) INTO __differing
    FROM default_view_definitions d
    FULL JOIN context_view_definitions() c ON c.view_name = d.view_name
    WHERE c.definition IS DISTINCT FROM d.definition;
    ASSERT __differing IS NULL, format( 'views defined otherwise than by default %s: %s', _state, __differing );
END;
$BODY$
;

-- Asserts the rows of the views of both contexts in every state of the horizon, the views generated in mode _mode.
CREATE OR REPLACE FUNCTION assert_views_in_every_horizon_state( _mode TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __in TEXT := format( ' (%s mode)', _mode );
    __rows BIGINT;
    __generic_before BIGINT;
    __generic_after BIGINT;
BEGIN
    UPDATE hafd.contexts SET fork_id = 2, irreversible_block = 4, current_block_num = 8 WHERE name = 'context';
    __rows := assert_context_views( 'context', 'fork 2 is visible up to block 8' || __in );
    PERFORM assert_operations_view_extended_plan( 'a', TRUE, 'fork 2 is visible up to block 8' || __in );
    -- blocks 1-4 irreversible, 5-8 reversible; block 7 of fork 2, block 8 of fork 2 (fork 3 is not seen yet)
    ASSERT ( SELECT array_agg( encode( hash, 'hex' ) ORDER BY num ) FROM a.blocks_view )
        = ARRAY[ 'badd10', 'badd20', 'badd30', 'badd40', 'badd50', 'badd60', 'badd72', 'badd82' ], 'blocks_view does not show fork 2 up to block 8' || __in;
    ASSERT ( SELECT array_agg( t.timestamp ORDER BY t.id ) FROM a.operations_view_extended t WHERE t.block_num = 7 )
        = ARRAY[ '2016-06-22 19:10:27-07'::timestamp, '2016-06-22 19:10:27-07'::timestamp ], 'operations of block 7 do not carry the timestamp of fork 2' || __in;

    UPDATE hafd.contexts SET fork_id = 3, irreversible_block = 4, current_block_num = 10 WHERE name = 'context';
    ASSERT assert_context_views( 'context', 'the context switched to fork 3' || __in ) > __rows, 'the switch to fork 3 shows no new rows' || __in;
    PERFORM assert_operations_view_extended_plan( 'a', TRUE, 'the context switched to fork 3' || __in );
    ASSERT ( SELECT array_agg( encode( hash, 'hex' ) ORDER BY num ) FROM a.blocks_view WHERE num > 6 )
        = ARRAY[ 'badd72', 'badd83', 'badd93', 'badd13' ], 'blocks_view does not show fork 3 after the switch' || __in;

    UPDATE hafd.contexts SET fork_id = 3, irreversible_block = 6, current_block_num = 10 WHERE name = 'context';
    PERFORM assert_context_views( 'context', 'blocks 5 and 6 are irreversible, but not in hafd.blocks' || __in );
    PERFORM assert_operations_view_extended_plan( 'a', TRUE, 'blocks 5 and 6 are irreversible, but not in hafd.blocks' || __in );

    UPDATE hafd.contexts SET fork_id = 3, irreversible_block = 5, current_block_num = 5 WHERE name = 'context';
    PERFORM assert_context_views( 'context', 'the context has no reversible range' || __in );
    PERFORM assert_operations_view_extended_plan( 'a', FALSE, 'the context has no reversible range' || __in );
    ASSERT ( SELECT max( num ) FROM a.blocks_view ) = 5, 'blocks_view shows reversible blocks without a reversible range' || __in;

    UPDATE hafd.contexts SET fork_id = 3, irreversible_block = 5, current_block_num = 3 WHERE name = 'context';
    PERFORM assert_context_views( 'context', 'the context is behind its irreversible block' || __in );
    PERFORM assert_operations_view_extended_plan( 'a', FALSE, 'the context is behind its irreversible block' || __in );
    ASSERT ( SELECT max( num ) FROM a.blocks_view ) = 3, 'blocks_view shows blocks after the current block of the context' || __in;

    UPDATE hafd.contexts SET fork_id = 2, irreversible_block = 4, current_block_num = 8 WHERE name = 'context_nf';
    PERFORM assert_context_views( 'context_nf', 'a non-forking context has blocks after its irreversible block' || __in );
    ASSERT ( SELECT max( num ) FROM b.blocks_view ) = 4, 'a non-forking blocks_view shows reversible blocks' || __in;

    UPDATE hafd.contexts SET fork_id = 2, irreversible_block = 5, current_block_num = 3 WHERE name = 'context_nf';
    PERFORM assert_context_views( 'context_nf', 'a non-forking context is behind its irreversible block' || __in );

    -- a role which may only read the views, as an API's
    UPDATE hafd.contexts SET fork_id = 2, irreversible_block = 4, current_block_num = 8 WHERE name = 'context';
    SET ROLE context_views_reader;
    SELECT count(*) INTO __rows FROM a.blocks_view;
    RESET ROLE;
    ASSERT __rows = 8, format( 'a role reading only the views sees %s blocks, not 8%s', __rows, __in );

    -- a cached generic plan reads the horizon when it runs, not when it was planned
    SET LOCAL plan_cache_mode = force_generic_plan;
    EXECUTE 'PREPARE context_blocks AS SELECT count(*) FROM a.blocks_view';
    EXECUTE 'EXECUTE context_blocks' INTO __generic_before;
    UPDATE hafd.contexts SET fork_id = 3, irreversible_block = 4, current_block_num = 10 WHERE name = 'context';
    EXECUTE 'EXECUTE context_blocks' INTO __generic_after;
    EXECUTE 'DEALLOCATE context_blocks';
    RESET plan_cache_mode;
    ASSERT ( __generic_before, __generic_after ) = ( 8::BIGINT, 10::BIGINT ), format( 'a generic plan saw %s and %s blocks, not 8 and 10%s', __generic_before, __generic_after, __in );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __c_definition RECORD;
BEGIN
    ASSERT hive.context_view_horizon_mode() = 'initplan', format( 'the default mode is %s, not initplan', hive.context_view_horizon_mode() );
    PERFORM hive.set_context_view_horizon_mode( 'initplan' );
    PERFORM assert_default_view_definitions( 'after switching to initplan mode' );
    PERFORM assert_views_in_every_horizon_state( 'initplan' );

    PERFORM hive.set_context_view_horizon_mode( 'c' );
    ASSERT hive.context_view_horizon_mode() = 'c', 'the mode is not c after switching to it';
    -- the views call the functions of libhfm themselves: no InitPlan, no ANY( ARRAY[ ... ] )
    FOR __c_definition IN SELECT * FROM context_view_definitions() LOOP
        ASSERT __c_definition.definition LIKE '%hive.context_view_horizon_min_block(%'
            AND __c_definition.definition NOT LIKE '%hive.context_view_horizon(%'
            AND __c_definition.definition NOT LIKE '%ANY (ARRAY[%'
            , format( '%s does not read the horizon through the functions of libhfm in c mode: %s', __c_definition.view_name, __c_definition.definition );
    END LOOP;
    PERFORM assert_views_in_every_horizon_state( 'c' );

    PERFORM hive.set_context_view_horizon_mode( 'initplan' );
    PERFORM assert_default_view_definitions( 'after switching back from c mode' );
END;
$BODY$
;
