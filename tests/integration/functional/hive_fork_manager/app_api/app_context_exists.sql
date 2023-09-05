
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __context_exists BOOL;
BEGIN
    SELECT hive.app_context_exists( 'context' ) INTO __context_exists;
    ASSERT __context_exists = TRUE, 'Context marked as not existed';

    SELECT hive.app_context_exists( 'context2' ) INTO __context_exists;
    ASSERT __context_exists = FALSE, 'Context marked as existed';
END
$BODY$
;





