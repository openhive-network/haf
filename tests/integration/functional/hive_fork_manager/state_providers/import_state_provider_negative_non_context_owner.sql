CREATE OR REPLACE PROCEDURE alice_test_given()
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
BEGIN
    BEGIN
        PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );
        ASSERT FALSE, 'No exception when haf_admin imports state provider to Alice''s context';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;





