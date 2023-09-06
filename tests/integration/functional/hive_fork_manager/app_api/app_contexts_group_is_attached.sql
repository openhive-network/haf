
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
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

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    CALL hive.appproc_context_detach( ARRAY[ 'context_detached_a', 'context_detached_b', 'context_detached_c' ] );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT hive.app_context_are_attached( ARRAY[ 'context_attached_a', 'context_attached_b', 'context_attached_c' ] ) ) = TRUE , 'Contexts are not attached';
    ASSERT ( SELECT hive.app_context_are_attached( ARRAY[ 'context_detached_a', 'context_detached_b', 'context_detached_c' ] ) ) = FALSE , 'Contexts are attached';
END;
$BODY$
;


