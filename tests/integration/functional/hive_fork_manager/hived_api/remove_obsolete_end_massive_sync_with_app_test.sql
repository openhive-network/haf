
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    -- simualte massive push by hived
    INSERT INTO hafd.blocks
    VALUES
       ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 10, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
         , (7, 'bob', 1)
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




