
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    CREATE SCHEMA B;
    CREATE SCHEMA C;

    PERFORM hive.app_create_context( 'context_attached_a' ,'a' );
    PERFORM hive.app_create_context( 'context_attached_b', 'b' );
    PERFORM hive.app_create_context( 'context_attached_c', 'c' );
    PERFORM hive.app_create_context( 'context_detached_a', 'a' );
    PERFORM hive.app_create_context( 'context_detached_b', 'b' );
    PERFORM hive.app_create_context( 'context_detached_c', 'c' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_context_detach( ARRAY[ 'context_detached_a', 'context_detached_b', 'context_detached_c' ] );
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


