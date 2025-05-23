
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    CREATE TABLE tab( id INT ) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hafd.state_providers_registered WHERE context_id = 1 AND state_provider = 'ACCOUNTS' AND tables = ARRAY[ 'context_accounts' ]::TEXT[] ) = 1, 'State provider not registered';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name  = 'context_accounts' ), 'Accounts table was not created';
    ASSERT ( SELECT COUNT(*) FROM hafd.registered_tables WHERE origin_table_schema = 'hafd' AND origin_table_name = 'context_accounts' AND context_id = 1 ) = 1, 'State provider table is not registered';
END;
$BODY$
;
