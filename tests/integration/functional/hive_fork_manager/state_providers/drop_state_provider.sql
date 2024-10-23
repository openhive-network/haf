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
    PERFORM hive.app_create_context( 'context', _schema => 'a', _is_forking =>TRUE, _is_attached => FALSE );

    PERFORM hive.app_state_provider_import( 'METADATA', 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_state_provider_drop( 'METADATA', 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hafd.state_providers_registered WHERE context_id = 1 AND state_provider = 'ACCOUNTS' AND tables = ARRAY[ 'context_accounts' ]::TEXT[] ) = 0, 'State provider is still registered';
    ASSERT NOT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'context_metadata' ), 'Accounts table still exists';
    ASSERT ( SELECT COUNT(*) FROM hafd.registered_tables WHERE origin_table_schema = 'hive' AND origin_table_name = 'context_metadata' AND context_id = 1 ) = 0, 'State provider table is still registered';

    ASSERT NOT EXISTS ( SELECT FROM hafd.triggers WHERE trigger_name='hafd.insert_trigger_hive_context_metadata' ), 'Insert trigger not cleaned';
    ASSERT NOT EXISTS ( SELECT FROM hafd.triggers WHERE trigger_name='hafd.update_trigger_hive_context_metadata' ), 'Update trigger not cleaned';
    ASSERT NOT EXISTS ( SELECT FROM hafd.triggers WHERE trigger_name='hafd.delete_trigger_hive_context_metadata' ), 'Delete trigger not cleaned';
    ASSERT NOT EXISTS ( SELECT FROM hafd.triggers WHERE trigger_name='hafd.truncate_trigger_hive_context_metadata' ), 'Truncate trigger not cleaned';

    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_insert_hive_context_metadata'), 'Insert trigger function not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_delete_hive_context_metadata'), 'Delete trigger function not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_update_hive_context_metadata'), 'Update trigger function not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_truncate_hive_context_metadata'), 'Truncate trigger function not dropped';
END;
$BODY$
;
