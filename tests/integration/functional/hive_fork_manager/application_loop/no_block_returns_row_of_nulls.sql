-- With no block to process yet, hive.app_next_iteration returns a hive.blocks_range
-- whose fields are NULL, not a NULL value: clients reading the OUT value (the
-- Python example applications) take its text form (,) for "no blocks".

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block INTEGER;
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'forking', _schema => 'a', _is_forking => TRUE, _stages => ARRAY[ hive.stage( 'MASSIVE', 100, 100 ), hafd.live_stage() ] );
    PERFORM hive.app_create_context( _name => 'nonforking', _schema => 'a', _is_forking => FALSE, _stages => ARRAY[ hive.stage( 'MASSIVE', 100, 100 ), hafd.live_stage() ] );
    CREATE TABLE A.results( name TEXT, wait BOOLEAN, blocks_range TEXT );

    FOR __block IN 1 .. 3 LOOP
        PERFORM hive.push_block(
             ( __block, ('\xBADD' || lpad( __block::TEXT, 2, '0' ))::bytea, '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , NULL, NULL, NULL
            , CASE WHEN __block = 1 THEN ARRAY[ ( 5, 'initminer', 1 )::hafd.accounts ] ELSE NULL END
            , NULL, NULL
        );
    END LOOP;
    PERFORM hive.set_irreversible( 3 );
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( 3 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
    __i INTEGER;
    __ctx TEXT;
    __wait BOOLEAN;
BEGIN
    FOREACH __ctx IN ARRAY ARRAY[ 'forking', 'nonforking' ] LOOP
        FOR __i IN 1 .. 10 LOOP
            CALL hive.app_next_iteration( ARRAY[ __ctx ], __blocks, _wait => FALSE );
            EXIT WHEN __blocks IS NULL AND ( SELECT current_block_num FROM hafd.contexts WHERE name = __ctx ) = 3;
        END LOOP;
        ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = __ctx ) = 3, __ctx || ' did not reach the head';

        FOREACH __wait IN ARRAY ARRAY[ FALSE, TRUE ] LOOP
            CALL hive.app_next_iteration( ARRAY[ __ctx ], __blocks, _wait => __wait );
            INSERT INTO A.results VALUES ( __ctx, __wait, __blocks::TEXT );
        END LOOP;
    END LOOP;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __row RECORD;
BEGIN
    ASSERT ( SELECT COUNT(*) FROM A.results ) = 4, 'both contexts must have been asked with and without _wait';
    FOR __row IN SELECT * FROM A.results LOOP
        ASSERT __row.blocks_range IS NOT DISTINCT FROM '(,)',
            FORMAT( '%s (_wait => %s): expected (,), got %s', __row.name, __row.wait, COALESCE( __row.blocks_range, 'NULL' ) );
    END LOOP;
END;
$BODY$
;
