-- The views of a context return their rows under a snapshot whose subtransaction XIDs have overflowed. Such a snapshot
-- is taken while another transaction holds more live subtransactions with an XID than a backend caches (64); the copy
-- of it a query runs under has no array of subtransaction XIDs, only their count, which is not zero when a transaction
-- listed before the overflowed one holds some. Two `holder` sessions hold the subtransactions, each one overflowed in
-- turn, as the order the snapshot lists them in is not known; the views are read in a third, `reader` session.

-- Opens a transaction in _holder with _subtransactions nested savepoints, each with an XID of its own.
CREATE OR REPLACE FUNCTION hold_subtransactions( _holder TEXT, _subtransactions INTEGER )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM dblink_exec( _holder, 'BEGIN' );
    PERFORM dblink_exec( _holder, 'INSERT INTO held VALUES ( 0 )' );
    PERFORM dblink_exec( _holder, string_agg( format( 'SAVEPOINT s%1$s; INSERT INTO held VALUES ( %1$s )', n ), '; ' ) )
    FROM generate_series( 1, _subtransactions ) n;
END;
$BODY$
;

-- Asserts that the views of the context, read in the reader session, show what is visible at block 3.
CREATE OR REPLACE FUNCTION assert_context_views( _state TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __blocks INTEGER[];
    __operations BIGINT[];
BEGIN
    SELECT b INTO __blocks FROM dblink( 'reader', 'SELECT array_agg( num ORDER BY num ) FROM a.blocks_view' ) AS t( b INTEGER[] );
    ASSERT __blocks = ARRAY[ 1, 2, 3 ], format( 'blocks_view shows the blocks %s, not 1 to 3, %s', __blocks, _state );
    SELECT o INTO __operations FROM dblink( 'reader', 'SELECT array_agg( id ORDER BY id ) FROM a.operations_view' ) AS t( o BIGINT[] );
    ASSERT __operations = ARRAY[ hafd.operation_id( 1, 0 ), hafd.operation_id( 2, 0 ), hafd.operation_id( 3, 0 ) ]
        , format( 'operations_view shows the operations %s, not the ones of blocks 1 to 3, %s', __operations, _state );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    CREATE SCHEMA a;
    PERFORM hive.app_create_context( _name => 'context', _schema => 'a' );

    INSERT INTO hafd.operation_types VALUES ( 1, 'OP 1', FALSE );
    INSERT INTO hafd.accounts( id, name, block_num ) VALUES ( 5, 'initminer', NULL );
    INSERT INTO hafd.blocks
    SELECT n, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000
    FROM generate_series( 1, 5 ) n;
    INSERT INTO hafd.operations( id, trx_in_block, op_type_id, op_pos, body_value )
    SELECT hafd.operation_id( n, 0 ), 0, 1, 0, '{"message":"OPERATION"}'::jsonb
    FROM generate_series( 1, 5 ) n;
    UPDATE hafd.contexts SET fork_id = 1, irreversible_block = 3, current_block_num = 3 WHERE name = 'context';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __connection TEXT := format( 'dbname=%s user=%s port=%s host=%s'
        , current_database(), current_user, current_setting( 'port' ), split_part( current_setting( 'unix_socket_directories' ), ',', 1 ) );
    __overflowed TEXT;
    __holders CONSTANT TEXT[] := ARRAY[ 'holder_1', 'holder_2' ];
    __holder TEXT;
BEGIN
    PERFORM dblink_connect( 'reader', __connection );
    FOREACH __holder IN ARRAY __holders LOOP
        PERFORM dblink_connect( __holder, __connection );
        PERFORM dblink_exec( __holder, 'CREATE TEMPORARY TABLE held( n INTEGER )' );
    END LOOP;

    FOREACH __overflowed IN ARRAY __holders LOOP
        FOREACH __holder IN ARRAY __holders LOOP
            PERFORM hold_subtransactions( __holder, CASE WHEN __holder = __overflowed THEN 70 ELSE 2 END );
        END LOOP;
        -- a snapshot lists a transaction only below its xmax, the XID after the last one completed
        PERFORM * FROM dblink( 'reader', 'SELECT pg_current_xact_id()::TEXT' ) AS t( x TEXT );
        PERFORM assert_context_views( format( 'while %s holds 70 subtransactions', __overflowed ) );
        FOREACH __holder IN ARRAY __holders LOOP
            PERFORM dblink_exec( __holder, 'ROLLBACK' );
        END LOOP;
    END LOOP;

    FOREACH __holder IN ARRAY __holders LOOP
        PERFORM dblink_disconnect( __holder );
    END LOOP;
    PERFORM dblink_disconnect( 'reader' );
END;
$BODY$
;
