-- Load test utilities
\ir ../test_tools.sql


CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- simualte massive push by hived
    -- Create blocks 1-5
    PERFORM test.create_blocks(1, 5);

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
         , (7, 'bob', 1)
    ;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.end_massive_sync(10);
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM hafd.events_queue WHERE event = 'MASSIVE_SYNC' AND block_num = 10 ), 'No event added';
    ASSERT ( SELECT COUNT(*) FROM hafd.events_queue ) = 3, 'Unexpected number of events';
END
$BODY$
;




