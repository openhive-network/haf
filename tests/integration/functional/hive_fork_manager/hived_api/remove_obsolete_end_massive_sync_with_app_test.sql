-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    -- simualte massive push by hived
    PERFORM test.create_blocks(1, 10);

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
         , (6, 'alice', hafd.make_block_id(1, 0))
         , (7, 'bob', hafd.make_block_id(1, 0))
    ;

    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.end_massive_sync(1);
    PERFORM hive.app_next_block( 'context' ); -- force to initialize context - event_id != 0, end_massive_sync 1
    PERFORM hive.end_massive_sync(2);
    PERFORM hive.end_massive_sync(3);
    PERFORM hive.app_next_block( 'context' ); -- eat MASSIVE_SYNC_EVENT 3
    PERFORM hive.end_massive_sync(6);
    PERFORM hive.end_massive_sync(10);
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    ASSERT EXISTS ( SELECT FROM hafd.events_queue WHERE event = 'MASSIVE_SYNC' AND block_num = 10 ), 'No event added';

    ASSERT ( SELECT COUNT(*) FROM hafd.events_queue ) = 5 , 'Unexpected number of events'; -- 0, 3,6, 10
    ASSERT ( SELECT COUNT(*) FROM hafd.events_queue WHERE block_num = 3 ) = 1, 'No MASSIVE SYNC EVENT(3)';
    ASSERT ( SELECT COUNT(*) FROM hafd.events_queue WHERE block_num = 6 ) = 1, 'No MASSIVE SYNC EVENT(6)';
    ASSERT ( SELECT COUNT(*) FROM hafd.events_queue WHERE block_num = 10 ) = 1, 'No MASSIVE SYNC EVENT(10)';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- MASSIVE_SYNC
    ASSERT __blocks.first_block = 2, 'Incorrect first block';
    ASSERT __blocks.last_block = 10, 'Incorrect last range';
END
$BODY$
;




