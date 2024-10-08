---------------------------- TEST PROVIDER ----------------------------------------------
CREATE OR REPLACE FUNCTION hive.start_provider_tests( _context hive_data.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    AS
$BODY$
DECLARE
    __table_1_name TEXT := _context || '_tests1';
    __table_2_name TEXT := _context || '_tests2';
BEGIN
    EXECUTE format( 'CREATE TABLE hive_data.%I(
                      id SERIAL
                    )', __table_1_name
    );

    EXECUTE format( 'CREATE TABLE hive_data.%I(
                      id SERIAL
                    )', __table_2_name
    );

    RETURN ARRAY[ __table_1_name, __table_2_name ];
END;
$BODY$
;

---------------------------END OF TEST PROVIDER -------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    ALTER TYPE hive_data.state_providers ADD VALUE 'TESTS';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE SCHEMA alice;
    CREATE TABLE alice.tab( id INT ) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );
    PERFORM hive.app_state_provider_import( 'TESTS', 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hive_data.state_providers_registered WHERE context_id = 1 AND state_provider = 'ACCOUNTS' AND tables = ARRAY[ 'context_accounts' ]::TEXT[] ) = 1, 'State provider not registered';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive_data' AND table_name  = 'context_accounts' ), 'Accounts table was not created';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive_data' AND table_name  = 'context_tests1' ), 'Tests1 table was not created';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive_data' AND table_name  = 'context_tests2' ), 'Tests2 table was not created';
    ASSERT ( SELECT COUNT(*) FROM hive_data.registered_tables WHERE origin_table_schema = 'hive_data' AND origin_table_name = 'context_accounts' AND context_id = 1 ) = 1, 'State provider table is not registered';
    ASSERT ( SELECT COUNT(*) FROM hive_data.registered_tables WHERE origin_table_schema = 'hive_data' AND origin_table_name = 'context_tests1' AND context_id = 1 ) = 1, 'State provider tests1 is not registered';
    ASSERT ( SELECT COUNT(*) FROM hive_data.registered_tables WHERE origin_table_schema = 'hive_data' AND origin_table_name = 'context_tests2' AND context_id = 1 ) = 1, 'State provider tests2 is not registered';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- bob as member of hive_applications_group got select permission for state provider tables
    PERFORM * FROM hive_data.context_accounts;
    PERFORM * FROM hive_data.context_tests1;
    PERFORM * FROM hive_data.context_tests2;
END;
$BODY$
;
