DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context_attached' );
    PERFORM hive.app_create_context( 'context_detached' );
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
    PERFORM hive.app_context_detach( 'context_detached' );
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT ( SELECT hive.app_context_is_attached( 'context_attached' ) ) = TRUE , 'Context is not attached';
    ASSERT ( SELECT hive.app_context_is_attached( 'context_detached' ) ) = FALSE , 'Context is attached';
END;
$BODY$
;


