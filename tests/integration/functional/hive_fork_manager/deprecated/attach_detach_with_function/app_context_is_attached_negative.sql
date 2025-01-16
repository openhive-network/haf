
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'context_attached', 'a' );
    PERFORM hive.app_create_context( 'context_detached', 'a' );
END;
$BODY$
;


CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        PERFORM hive.app_context_detach( 'not_existed_context' );
        ASSERT FALSE, 'No expected exception for a non existed context';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;


