
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES
    ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 3, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
    ;

    PERFORM hive.end_massive_sync(2);

    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp );

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'attached_context', 'a' );
    PERFORM hive.app_create_context( 'attached_context2', 'a' );
    PERFORM hive.app_create_context( 'attached_context_not_insync_bn', 'a' );
    PERFORM hive.app_create_context( 'attached_context_not_insync_ir', 'a' );
    PERFORM hive.app_create_context( 'attached_context_not_insync_ev', 'a' );
    PERFORM hive.app_create_context( 'attached_context_not_insync_fr', 'a' );
    PERFORM hive.app_create_context( 'attached_context_not_insync_is_forking', _schema => 'a', _is_forking => FALSE );
    PERFORM hive.app_create_context( 'attached_context_not_insync_loop', _schema => 'a' );

    UPDATE hafd.contexts ctx
    SET
        current_block_num = 1
      , irreversible_block = 1
      , back_from_fork = FALSE
      , events_id = 0
      , fork_id = 1
    ;

    UPDATE hafd.contexts ctx
    SET
        current_block_num = 2
    WHERE ctx.name = 'attached_context_not_insync_bn'
    ;

    UPDATE hafd.contexts ctx
    SET
        irreversible_block = 2
    WHERE ctx.name = 'attached_context_not_insync_ir'
    ;

    UPDATE hafd.contexts ctx
    SET
        events_id = 1
    WHERE ctx.name = 'attached_context_not_insync_ev'
    ;

    UPDATE hafd.contexts ctx
    SET
        fork_id = 2
    WHERE ctx.name = 'attached_context_not_insync_fr'
    ;

    UPDATE hafd.contexts ctx
    SET
        loop = (10, hafd.live_stage(), 10, 10, 10)::hafd.application_loop_state
    WHERE ctx.name = 'attached_context_not_insync_loop'
    ;

END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
BEGIN
    PERFORM hive.app_check_contexts_synchronized( ARRAY[ 'attached_context', 'attached_context2' ] );

    BEGIN
        PERFORM hive.app_check_contexts_synchronized( ARRAY[ 'attached_context', 'attached_context_not_insync_bn' ] );
        ASSERT FALSE, 'No expected exception for block num difference';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_check_contexts_synchronized( ARRAY[ 'attached_context', 'attached_context_not_insync_ir' ] );
    EXCEPTION WHEN OTHERS THEN
        ASSERT FALSE, 'Eexception for block irreversible difference';
    END;

    BEGIN
        PERFORM hive.app_check_contexts_synchronized( ARRAY[ 'attached_context', 'attached_context_not_insync_ev' ] );
            ASSERT FALSE, 'No expected exception for event id difference';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_check_contexts_synchronized( ARRAY[ 'attached_context', 'attached_context_not_insync_fr' ] );
    EXCEPTION WHEN OTHERS THEN
        ASSERT FALSE, 'Exception for fork id difference';
    END;

    BEGIN
        PERFORM hive.app_check_contexts_synchronized( ARRAY[ 'attached_context', 'attached_context_not_insync_is_forking' ] );
        ASSERT FALSE, 'No expected exception for is_forking difference';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_check_contexts_synchronized( ARRAY[ 'attached_context', 'attached_context_not_insync_loop' ] );
        ASSERT FALSE, 'No expected exception for loop difference';
    EXCEPTION WHEN OTHERS THEN
    END;

END;
$BODY$
;





