DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );
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
    PERFORM hive.app_remove_context( 'context' );
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT * FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'context_accounts' ), 'Accounts table was not removed';
    ASSERT NOT EXISTS ( SELECT * FROM hive.state_providers_registered WHERE context_id = 1 AND state_provider = 'ACCOUNTS' ), 'State provider is still registered';
END;
$BODY$
;
