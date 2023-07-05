DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context_attached_a' );
    PERFORM hive.app_create_context( 'context_attached_b' );
    PERFORM hive.app_create_context( 'context_attached_c' );
    PERFORM hive.app_create_context( 'context_detached_a' );
    PERFORM hive.app_create_context( 'context_detached_b' );
    PERFORM hive.app_create_context( 'context_detached_c' );
    PERFORM hive.app_context_detach( ARRAY[ 'context_detached_a', 'context_detached_b', 'context_detached_c' ] );
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
    BEGIN
        PERFORM hive.app_contexts_are_attached( ARRAY[ 'context_detached_a', 'context_detached_b', 'context_attached_c' ] );
        ASSERT FALSE, 'No exception when detached/attached contexts are mixed in a group';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_contexts_are_attached( ARRAY[ 'context_detached_a', 'context_not_existed' ] );
        ASSERT FALSE, 'No exception when not existed context in a group';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_contexts_are_attached( ARRAY[] );
        ASSERT FALSE, 'No exception when empty array of contexts';
    EXCEPTION WHEN OTHERS THEN
    END;

END;
$BODY$
;



