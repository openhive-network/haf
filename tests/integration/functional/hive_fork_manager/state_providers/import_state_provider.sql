---------------------------- TEST PROVIDER ----------------------------------------------
CREATE OR REPLACE FUNCTION hive.start_provider_tests( _context hive.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __table_1_name TEXT := _context || '_tests1';
    __table_2_name TEXT := _context || '_tests2';
BEGIN
    EXECUTE format( 'CREATE TABLE hive.%I(
                      id SERIAL
                    )', __table_1_name
    );

    EXECUTE format( 'CREATE TABLE hive.%I(
                      id SERIAL
                    )', __table_2_name
    );

    RETURN ARRAY[ __table_1_name, __table_2_name ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_state_provider_tests( _first_block hive.blocks.num%TYPE, _last_block hive.blocks.num%TYPE, _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- INTENTIONALLY EMPTY - NOT REQUIRED BY THE TEST
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.drop_state_provider_tests( _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- INTENTIONALLY EMPTY - NOT REQUIRED BY THE TEST
END;
$BODY$
;
---------------------------END OF TEST PROVIDER -------------------------------------------------------------------

DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    ALTER TYPE hive.state_providers ADD VALUE 'TESTS';

    PERFORM hive.app_create_context( 'context' );
    CREATE TABLE tab( id INT ) INHERITS( hive.context );
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
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );
    PERFORM hive.app_state_provider_import( 'TESTS', 'context' );
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
    ASSERT ( SELECT COUNT(*) FROM hive.state_providers_registered WHERE context_id = 1 AND state_provider = 'ACCOUNTS' AND tables = ARRAY[ 'context_accounts' ]::TEXT[] ) = 1, 'State provider not registered';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'context_accounts' ), 'Accounts table was not created';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'context_tests1' ), 'Tests1 table was not created';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'context_tests2' ), 'Tests2 table was not created';
    ASSERT ( SELECT COUNT(*) FROM hive.registered_tables WHERE origin_table_schema = 'hive' AND origin_table_name = 'context_accounts' AND context_id = 1 ) = 1, 'State provider table is not registered';
    ASSERT ( SELECT COUNT(*) FROM hive.registered_tables WHERE origin_table_schema = 'hive' AND origin_table_name = 'context_tests1' AND context_id = 1 ) = 1, 'State provider tests1 is not registered';
    ASSERT ( SELECT COUNT(*) FROM hive.registered_tables WHERE origin_table_schema = 'hive' AND origin_table_name = 'context_tests2' AND context_id = 1 ) = 1, 'State provider tests2 is not registered';
END;
$BODY$
;
