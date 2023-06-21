DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- Initialization
    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync( 1 ); -- eid=1
    -- End of  Initialization

    -- Preparing contexts
    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_create_context( 'slow_context' ); -- it holds events queue

    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );
    -- End of preparing contexts

    PERFORM hive.push_block(
                   ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-04'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
    ); -- eid=2



    PERFORM hive.push_block(
                   ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
    ); -- eid=3

    PERFORM hive.set_irreversible(2); -- eid=4

    PERFORM hive.app_next_block( 'context' ); -- (1,2) NB(3) ctx.eid=3
    PERFORM hive.app_next_block( 'context' ); -- (2,2) NB(3) ctx.eid=3

    PERFORM hive.back_from_fork( 2 ); -- eid=5

    PERFORM hive.app_next_block( 'context' ); -- (3,3) ctx.eid=3 NB(3)
    PERFORM hive.app_next_block( 'context' ); -- NULL, ctx.eid=4 NI(2)

    PERFORM hive.app_next_block( 'context' ); -- NULL ctx.eid=5 BFF(2)

    -- Now the context if on BFF(2) event and waits for new blocks in a new fork
    -- Push new version of block 3 is pushed
    PERFORM hive.push_block(
                   ( 3, '\xBADD31', '\xCAFE31', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               ); -- eid=6

    -- events queue content:
    -- 0: NI(0)
    -- 1: MS(1)
    -- 2: NB(2)
    -- 3: NB(3)  <- old version of block 3
    -- 4: NI(2)
    -- 5: BFF(3) <- the 'context' is here now
    -- 6: NB(3)  <- new version of block 3
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- precondition, the context is on BFF(2) event
    ASSERT ( SELECT hc.events_id FROM hive.contexts hc WHERE hc.name = 'context' ) = 5, 'The context is not on BFF(2) event';
    -- the contex is moving forward, it is expected next move will set in on new version of block 3 eid=6
    PERFORM hive.app_next_block( 'context' );
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    -- check if context is on desire event
    -- if it will back to ctx.eid < 5 (state before last move) than it is a fatal issue which may ends with
    -- constraint violation when a new NEW_IRREVERSIBLE event will be pushed and events queue is cleared
    -- from already processed events: DELETE operation on hive.events_queue takes eid=5 as an upper bound, but after the context move
    -- its ctx may back to eid=3, and DELETE will fail what stops the hived process
    ASSERT ( SELECT hc.events_id FROM hive.contexts hc WHERE hc.name = 'context' ) = 6, 'Wrong events_id after move context in new fork';
END
$BODY$
;




