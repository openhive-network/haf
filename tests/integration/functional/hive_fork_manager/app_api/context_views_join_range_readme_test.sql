-- The example queries of "Joining a context's views: where to put the block range" in src/hive_fork_manager/Readme.md,
-- copied unchanged, run against a forking context with both irreversible and reversible blocks in the range, and
-- also with operations_view in place of operations_view_extended. With the range on the operations side the
-- irreversible operations are read by index, not scanned.

CREATE OR REPLACE FUNCTION readme_query_plan( _query TEXT )
    RETURNS JSONB
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __plan JSON;
BEGIN
    EXECUTE 'EXPLAIN ( ANALYZE, FORMAT JSON ) ' || _query INTO __plan;
    RETURN __plan::JSONB;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA app;
    PERFORM hive.app_create_context( _name => 'context', _schema => 'app' );

    INSERT INTO hafd.operation_types VALUES ( 1, 'OP 1', FALSE );
    INSERT INTO hafd.accounts( id, name, block_num ) VALUES ( 5, 'initminer', NULL );

    INSERT INTO hafd.blocks
    SELECT n, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000
    FROM generate_series( 1, 5000 ) n;

    INSERT INTO hafd.operations( id, trx_in_block, op_pos, op_type_id, body_value )
    SELECT hafd.operation_id( n, pos ), 0, pos, 1, '{}'::jsonb
    FROM generate_series( 1, 5000 ) n, generate_series( 0, 9 ) pos;

    INSERT INTO hafd.blocks_reversible
    SELECT n, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1
    FROM generate_series( 4990, 5010 ) n;

    INSERT INTO hafd.operations_reversible( id, trx_in_block, op_pos, op_type_id, body_value, fork_id )
    SELECT hafd.operation_id( n, pos ), 0, pos, 1, '{}'::jsonb, 1
    FROM generate_series( 4990, 5010 ) n, generate_series( 0, 9 ) pos;

    ANALYZE hafd.blocks, hafd.operations, hafd.blocks_reversible, hafd.operations_reversible;

    UPDATE hafd.contexts SET fork_id = 1, irreversible_block = 5000, current_block_num = 5005;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __single_block CONSTANT TEXT :=
'SELECT ov.id, ov.op_type_id, ov.body, bv.created_at
FROM app.operations_view_extended ov
JOIN app.blocks_view bv ON bv.num = ov.block_num
WHERE ov.block_num = 5000';
    __range CONSTANT TEXT :=
'SELECT ov.id, ov.op_type_id, ov.body, bv.created_at
FROM app.operations_view_extended ov
JOIN app.blocks_view bv ON bv.num = ov.block_num
WHERE ov.block_num BETWEEN 4996 AND 5005
  AND bv.num BETWEEN 4996 AND 5005';
    __count BIGINT;
    __plan JSONB;
BEGIN
    EXECUTE format( 'SELECT count(*) FROM ( %s ) q', __single_block ) INTO __count;
    ASSERT __count = 10, format( 'the single-block example returns %s rows, not the 10 operations of block 5000', __count );
    EXECUTE format( 'SELECT count(*) FROM ( %s ) q', __range ) INTO __count;
    ASSERT __count = 100, format( 'the range example returns %s rows, not the 100 operations of blocks 4996-5005', __count );

    EXECUTE format( 'SELECT count(*) FROM ( %s ) q', replace( __single_block, 'operations_view_extended', 'operations_view' ) ) INTO __count;
    ASSERT __count = 10, format( 'the single-block example on operations_view returns %s rows, not 10', __count );
    EXECUTE format( 'SELECT count(*) FROM ( %s ) q', replace( __range, 'operations_view_extended', 'operations_view' ) ) INTO __count;
    ASSERT __count = 100, format( 'the range example on operations_view returns %s rows, not 100', __count );

    __plan := readme_query_plan( __single_block );
    ASSERT NOT jsonb_path_exists( __plan, 'lax $.** ? ( @."Node Type" == "Seq Scan" && @."Relation Name" == "operations" )' )
        , format( 'the single-block example scans hafd.operations: %s', __plan );
    __plan := readme_query_plan( __range );
    ASSERT NOT jsonb_path_exists( __plan, 'lax $.** ? ( @."Node Type" == "Seq Scan" && @."Relation Name" == "operations" )' )
        , format( 'the range example scans hafd.operations: %s', __plan );
END;
$BODY$
;
