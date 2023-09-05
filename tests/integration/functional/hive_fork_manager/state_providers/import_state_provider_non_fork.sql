
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context', FALSE );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hive.state_providers_registered WHERE context_id = 1 AND state_provider = 'ACCOUNTS' AND tables = ARRAY[ 'context_accounts' ]::TEXT[] ) = 1, 'State provider not registered';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'context_accounts' ), 'Accounts table was not created';
    ASSERT ( SELECT COUNT(*) FROM hive.registered_tables WHERE origin_table_schema = 'hive' AND origin_table_name = 'context_accounts' AND context_id = 1 ) = 0, 'State provider table is registered';
END;
$BODY$
;
