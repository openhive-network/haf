-- A single-block join of a context's operations_view with its blocks_view, with no range on blocks_view, probes
-- pk_hive_blocks once per operation in a nested loop, and a context with no reversible range does not probe the
-- reversible tables. Only the plan's shape is checked: a test database is far too small to show the timing.

CREATE OR REPLACE FUNCTION single_block_join_plan( _schema TEXT, _block_num INT )
    RETURNS JSONB
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __plan JSON;
BEGIN
    EXECUTE format(
          'EXPLAIN ( ANALYZE, FORMAT JSON ) SELECT count(*) FROM %1$I.operations_view ov JOIN %1$I.blocks_view bv ON bv.num = ov.block_num WHERE ov.block_num BETWEEN %2$s AND %2$s'
        , _schema, _block_num )
    INTO __plan;
    RETURN __plan::JSONB;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION assert_probes_blocks_per_operation( _plan JSONB, _context TEXT )
    RETURNS void
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
BEGIN
    ASSERT jsonb_path_exists( _plan, 'lax $.** ? ( @."Node Type" == "Nested Loop" )' )
        , format( 'the join through the views of %s is not a nested loop: %s', _context, _plan );
    -- probed by the join key, the block number of the outer operation
    ASSERT jsonb_path_exists( _plan, 'lax $.** ? ( @."Index Name" == "pk_hive_blocks" && @."Index Cond" like_regex "num = .*operation_id_to_block_num" )' )
        , format( 'the join through the views of %s does not probe pk_hive_blocks per operation: %s', _context, _plan );
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

    INSERT INTO hafd.operation_types VALUES ( 1, 'OP 1', FALSE );
    INSERT INTO hafd.accounts( id, name, block_num ) VALUES ( 5, 'initminer', NULL );

    INSERT INTO hafd.blocks
    SELECT n, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000
    FROM generate_series( 1, 5000 ) n;

    INSERT INTO hafd.operations( id, trx_in_block, op_type_id, op_pos, body_value )
    SELECT hafd.operation_id( n, pos ), 0, 1, pos, '{}'::jsonb
    FROM generate_series( 1, 5000 ) n, generate_series( 0, 9 ) pos;

    INSERT INTO hafd.blocks_reversible
    SELECT n, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1
    FROM generate_series( 4990, 5010 ) n;

    INSERT INTO hafd.operations_reversible( id, trx_in_block, op_type_id, op_pos, body_value, fork_id )
    SELECT hafd.operation_id( n, pos ), 0, 1, pos, '{}'::jsonb, 1
    FROM generate_series( 4990, 5010 ) n, generate_series( 0, 9 ) pos;

    ANALYZE hafd.blocks, hafd.operations, hafd.blocks_reversible, hafd.operations_reversible;

    UPDATE hafd.contexts SET fork_id = 1, irreversible_block = 5000, current_block_num = 5000;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __plan JSONB;
BEGIN
    __plan := single_block_join_plan( 'a', 2500 );
    PERFORM assert_probes_blocks_per_operation( __plan, 'a forking context' );
    ASSERT jsonb_path_exists( __plan, 'lax $.** ? ( @."Relation Name" == "blocks_reversible" && @."Actual Loops" == 0 )' )
        , format( 'the plan of a forking context has no reversible branch: %s', __plan );
    ASSERT NOT jsonb_path_exists( __plan, 'lax $.** ? ( @."Relation Name" like_regex "_reversible$" && @."Actual Loops" > 0 )' )
        , format( 'a forking context without a reversible range probes the reversible tables: %s', __plan );

    __plan := single_block_join_plan( 'b', 2500 );
    PERFORM assert_probes_blocks_per_operation( __plan, 'a non-forking context' );
    ASSERT NOT jsonb_path_exists( __plan, 'lax $.** ? ( @."Relation Name" like_regex "_reversible$" )' )
        , format( 'the plan of a non-forking context reads the reversible tables: %s', __plan );

    -- with a reversible range the reversible branch runs, and still returns only the visible fork's operations
    UPDATE hafd.contexts SET current_block_num = 5005 WHERE name = 'context';
    __plan := single_block_join_plan( 'a', 5003 );
    ASSERT jsonb_path_exists( __plan, 'lax $.** ? ( @."Relation Name" == "operations_reversible" && @."Actual Loops" > 0 )' )
        , format( 'a forking context with a reversible range does not read the reversible operations: %s', __plan );
    ASSERT ( SELECT count(*) FROM a.operations_view ov JOIN a.blocks_view bv ON bv.num = ov.block_num WHERE ov.block_num BETWEEN 5003 AND 5003 ) = 10
        , 'the join through the views does not return the 10 operations of a reversible block';
END;
$BODY$
;
