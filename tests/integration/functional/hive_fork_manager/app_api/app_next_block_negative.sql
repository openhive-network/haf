
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'detached_context', 'a' );
    PERFORM hive.app_context_detach( 'detached_context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
BEGIN
    BEGIN
        PERFORM hive.app_next_block( 'context' );
        ASSERT FALSE, 'No expected exception for unexisted context';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;





