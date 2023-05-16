DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context_a' );
    PERFORM hive.app_create_context( 'context_b' );
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
    __result BOOLEAN := FALSE;
BEGIN
    SELECT hive.app_context_are_attached( ARRAY[ 'context_a', 'context_b'] ) INTO __result;

    ASSERT __result, 'Returned wrong contexts attachment state';
END;
$BODY$
;


