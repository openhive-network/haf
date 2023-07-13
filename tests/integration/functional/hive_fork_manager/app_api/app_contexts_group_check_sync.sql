DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES
    ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 3, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
    ;

    PERFORM hive.end_massive_sync(2);

    INSERT INTO hive.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp );

    PERFORM hive.app_create_context( 'attached_context' );
    PERFORM hive.app_create_context( 'attached_context2' );
    PERFORM hive.app_create_context( 'attached_context_not_insync_bn' );
    PERFORM hive.app_create_context( 'attached_context_not_insync_ir' );
    PERFORM hive.app_create_context( 'attached_context_not_insync_ev' );
    PERFORM hive.app_create_context( 'attached_context_not_insync_fr' );
    PERFORM hive.app_create_context( 'attached_context_not_insync_db' );
    PERFORM hive.app_create_context( 'attached_context_not_insync_is_forking', FALSE );

    UPDATE hive.contexts ctx
    SET
        current_block_num = 1
      , irreversible_block = 1
      , back_from_fork = FALSE
      , events_id = 0
      , fork_id = 1
      , detached_block_num = 1
    ;

    UPDATE hive.contexts ctx
    SET
        current_block_num = 2
    WHERE ctx.name = 'attached_context_not_insync_bn'
    ;

    UPDATE hive.contexts ctx
    SET
        irreversible_block = 2
    WHERE ctx.name = 'attached_context_not_insync_ir'
    ;

    UPDATE hive.contexts ctx
    SET
        events_id = 1
    WHERE ctx.name = 'attached_context_not_insync_ev'
    ;

    UPDATE hive.contexts ctx
    SET
        fork_id = 2
    WHERE ctx.name = 'attached_context_not_insync_fr'
    ;

    UPDATE hive.contexts ctx
    SET
        detached_block_num = 2
    WHERE ctx.name = 'attached_context_not_insync_db'
    ;

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
        PERFORM hive.app_check_contexts_synchronized( ARRAY[ 'attached_context', 'attached_context_not_insync_db' ] );
        ASSERT FALSE, 'No expected exception for detached block num difference';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_check_contexts_synchronized( ARRAY[ 'attached_context', 'attached_context_not_insync_is_forking' ] );
        ASSERT FALSE, 'No expected exception for is_forking difference';
    EXCEPTION WHEN OTHERS THEN
    END;

END;
$BODY$
;





