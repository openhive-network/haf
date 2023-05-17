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
    PERFORM hive.app_context_detach( ARRAY[ 'context_detached_a', 'context_detached_b', 'context_detached_c' ] );
END;
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
    ASSERT ( SELECT hive.app_contexts_are_attached( ARRAY[ 'context_attached_a', 'context_attached_b', 'context_attached_c' ] ) ) = TRUE , 'Contexts are not attached';
    ASSERT ( SELECT hive.app_contexts_are_attached( ARRAY[ 'context_detached_a', 'context_detached_b', 'context_detached_c' ] ) ) = FALSE , 'Contexts are attached';
END;
$BODY$
;


