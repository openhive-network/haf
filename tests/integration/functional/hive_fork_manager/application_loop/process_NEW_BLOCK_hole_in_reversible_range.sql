-- A forking context without dependencies in the reversible range whose next NEW_BLOCK
-- skips a block that is not irreversible: that hole is impossible, so it must still
-- be rejected with 'current_block_num is reversible!'.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block INTEGER;
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'context', _schema => 'a', _is_forking => TRUE, _stages => ARRAY[ hive.stage( 'MASSIVE', 100, 100 ), hafd.live_stage() ] );

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
    __block INTEGER;
    __message TEXT;
BEGIN
    -- the update variant re-creates hive.get_estimated_hive_head_block() after 'given',
    -- which drops the mock
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( 3 );

    PERFORM hive.push_block(
         ( 4, '\xBADD04', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );
    PERFORM test.set_head_block_num( 4 );
    FOR __i IN 1 .. 10 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks, _wait => FALSE );
        EXIT WHEN ( SELECT current_block_num FROM hafd.contexts WHERE name = 'context' ) = 4;
    END LOOP;
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'context' ) = 4, 'context did not process block 4';
    ASSERT hive.get_current_stage_name( 'context' ) = 'live', 'context is not live';

    FOR __block IN 5 .. 6 LOOP
        PERFORM hive.push_block(
             ( __block, ('\xBADD' || lpad( __block::TEXT, 2, '0' ))::bytea, '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , NULL, NULL, NULL, NULL, NULL, NULL
        );
    END LOOP;
    PERFORM test.set_head_block_num( 6 );
    DELETE FROM hafd.events_queue WHERE event = 'NEW_BLOCK' AND block_num = 5;

    BEGIN
        PERFORM hive.app_next_block( ARRAY[ 'context' ], FALSE );
        ASSERT FALSE, 'A hole in the reversible range was not rejected';
    EXCEPTION WHEN assert_failure THEN
        GET STACKED DIAGNOSTICS __message = MESSAGE_TEXT;
        ASSERT __message = 'current_block_num is reversible!', 'Wrong error for a hole in the reversible range: ' || __message;
    END;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'context' ) = 4, 'context moved past the hole';
END;
$BODY$
;
