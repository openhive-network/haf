
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context_a' );
    PERFORM hive.app_create_context( 'context_b' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
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


