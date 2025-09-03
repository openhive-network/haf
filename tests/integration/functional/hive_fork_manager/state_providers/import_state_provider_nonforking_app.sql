CREATE OR REPLACE FUNCTION hafd.create_function_a()
    RETURNS VOID
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    EXECUTE 'CREATE OR REPLACE FUNCTION hive.a()
            RETURNS VOID
            LANGUAGE plpgsql
            AS
            $BODY2$
            BEGIN
            END;
            $BODY2$;
        ';
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    ALTER TYPE hafd.state_providers ADD VALUE 'TESTS';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a', _is_forking => False   );
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
    ---------------------------- TEST PROVIDER ----------------------------------------------
    EXECUTE 'CREATE OR REPLACE FUNCTION hive.start_provider_tests( _context hafd.context_name )
        RETURNS TEXT[]
        LANGUAGE plpgsql
    AS
    $$
    DECLARE
        __table_1_name TEXT := _context || ''_tests1'';
        __table_2_name TEXT := _context || ''_tests2'';
    BEGIN
        EXECUTE format( ''CREATE TABLE hafd.%I(
                      id SERIAL
                    )'', __table_1_name
                );

        EXECUTE format( ''CREATE TABLE hafd.%I(
                      id SERIAL
                    )'', __table_2_name
                );

        RETURN ARRAY[ __table_1_name, __table_2_name ];
    END;
    $$
    ;';

    EXECUTE 'CREATE OR REPLACE FUNCTION hive.runtimecode_provider_tests(_context hafd.context_name)
    RETURNS VOID
    LANGUAGE plpgsql
    AS
    $$
    BEGIN
        PERFORM hafd.create_function_a();
    END;
    $$;';

---------------------------END OF TEST PROVIDER -------------------------------------------------------------------

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
    ASSERT ( SELECT COUNT(*) FROM hafd.state_providers_registered WHERE context_id = 1 AND state_provider = 'ACCOUNTS' AND tables = ARRAY[ 'context_accounts' ]::TEXT[] ) = 1, 'State provider not registered';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name  = 'context_accounts' ), 'Accounts table was not created';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name  = 'context_tests1' ), 'Tests1 table was not created';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name  = 'context_tests2' ), 'Tests2 table was not created';

    ASSERT EXISTS (
        SELECT 1
        FROM pg_proc
        JOIN pg_namespace ON pg_proc.pronamespace = pg_namespace.oid
        WHERE pg_proc.proname = 'a' AND pg_namespace.nspname = 'hive'
    ), 'Function hive.a does not exists';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- bob as member of hive_applications_group got select permission for state provider tables
    PERFORM * FROM hafd.context_accounts;
    PERFORM * FROM hafd.context_tests1;
    PERFORM * FROM hafd.context_tests2;
END;
$BODY$
;
