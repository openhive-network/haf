DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- simualte massive push by hived
    INSERT INTO hive.blocks
    VALUES
       ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
     , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp )
     , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp )
     , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp )
     , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp )
     , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp )
     , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp )
     , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp )
     , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp )
     , ( 10, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:30-07'::timestamp )
    ;

    PERFORM hive.app_create_context( 'context' );
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
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

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    ASSERT EXISTS ( SELECT FROM hive.events_queue WHERE event = 'MASSIVE_SYNC' AND block_num = 10 ), 'No event added';

    ASSERT ( SELECT COUNT(*) FROM hive.events_queue ) = 4 , 'Unexpected number of events'; -- 0, 3,6, 10
    ASSERT ( SELECT COUNT(*) FROM hive.events_queue WHERE block_num = 3 ) = 1, 'No MASSIVE SYNC EVENT(3)';
    ASSERT ( SELECT COUNT(*) FROM hive.events_queue WHERE block_num = 6 ) = 1, 'No MASSIVE SYNC EVENT(6)';
    ASSERT ( SELECT COUNT(*) FROM hive.events_queue WHERE block_num = 10 ) = 1, 'No MASSIVE SYNC EVENT(10)';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- MASSIVE_SYNC
    ASSERT __blocks.first_block = 3, 'Incorrect first block';
    ASSERT __blocks.last_block = 10, 'Incorrect last range';
END
$BODY$
;




