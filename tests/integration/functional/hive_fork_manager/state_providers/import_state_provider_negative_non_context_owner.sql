DROP FUNCTION IF EXISTS alice_test_given;
CREATE FUNCTION alice_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
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
    BEGIN
        PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );
        ASSERT FALSE, 'No exception when haf_admin imports state provider to Alice''s context';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;





