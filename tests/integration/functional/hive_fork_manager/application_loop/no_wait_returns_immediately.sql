-- hive.app_next_iteration( ..., _wait => FALSE ) must return NULL right away when
-- there is nothing to process, instead of blocking inside the database in
-- hive.wait_for_new_block (issue #341: block-processing drivers idle on their own
-- connection and consume the LISTEN notifications themselves).

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
    CREATE TABLE A.timing( name TEXT, elapsed INTERVAL );

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
    __start TIMESTAMPTZ;
    __i INTEGER;
    __ctx TEXT;
BEGIN
    FOREACH __ctx IN ARRAY ARRAY[ 'forking', 'nonforking' ] LOOP
        -- drain the three blocks (live stage: one block per iteration at most)
        FOR __i IN 1 .. 10 LOOP
            CALL hive.app_next_iteration( ARRAY[ __ctx ], __blocks, _wait => FALSE );
            EXIT WHEN __blocks IS NULL AND ( SELECT current_block_num FROM hafd.contexts WHERE name = __ctx ) = 3;
        END LOOP;
        ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = __ctx ) = 3, __ctx || ' did not reach the head';

        -- now at head: five empty iterations must not wait
        __start := clock_timestamp();
        FOR __i IN 1 .. 5 LOOP
            CALL hive.app_next_iteration( ARRAY[ __ctx ], __blocks, _wait => FALSE );
            ASSERT __blocks IS NULL, __ctx || ': unexpected range ' || __blocks::TEXT;
        END LOOP;
        INSERT INTO A.timing VALUES ( __ctx, clock_timestamp() - __start );
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
    FOR __row IN SELECT * FROM A.timing LOOP
        -- with _wait the same five iterations would take >= 5 * 0.25 s (latch wake)
        -- or up to 5 * 4 s (timeout); without it they are pure bookkeeping
        ASSERT __row.elapsed < '1 second'::INTERVAL,
            FORMAT( '%s: five empty no-wait iterations took %s', __row.name, __row.elapsed );
    END LOOP;
    ASSERT ( SELECT COUNT(*) FROM A.timing ) = 2, 'both loop flavours must have been measured';
END;
$BODY$
;
