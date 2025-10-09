-- ===================================================================
-- Test: hive.app_transaction_table_unregister
-- Purpose: verify that unregistering removes triggers, shadow table,
--          trigger functions, and updates registered_tables array.
-- ===================================================================

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;

    -- ensure context exists
    PERFORM hive.app_create_context(_name => 'context_unregister', _schema => 'a', _is_forking => false);

    -- create table and register rollback support
    CREATE TABLE a.table_unregister(
                                       id   SERIAL PRIMARY KEY,
                                       smth INTEGER,
                                       name TEXT
    );

    PERFORM hive.app_transaction_table_register('a', 'table_unregister', 'context_unregister');

    -- sanity checks before unregister
    ASSERT EXISTS (
        SELECT 1 FROM information_schema.tables WHERE table_schema='hafd' AND table_name='shadow_a_table_unregister'
    ), 'Expected shadow table before unregister';
    ASSERT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname='hafd.insert_trigger_a_table_unregister'
    ), 'Expected insert trigger before unregister';
    ASSERT EXISTS (
        SELECT 1 FROM hafd.applications_transactions_register
        WHERE name='context_unregister'
          AND 'a.table_unregister' = ANY(registered_tables)
    ), 'Expected table to be listed in registered_tables array before unregister';
END;
$BODY$;

-- ===================================================================
-- WHEN: unregister the table
-- ===================================================================
CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_transaction_table_unregister('context_unregister', 'a', 'table_unregister');
END;
$BODY$;

-- ===================================================================
-- THEN: verify cleanup of triggers, functions, shadow table, and array
-- ===================================================================
CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    -- Shadow table should be gone
    ASSERT NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema='hafd' AND table_name='shadow_a_table_unregister'
    ), 'Shadow table was not dropped';

    -- All triggers should be gone
    ASSERT NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='hafd.insert_trigger_a_table_unregister'),
        'Insert trigger still exists';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='hafd.delete_trigger_a_table_unregister'),
        'Delete trigger still exists';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='hafd.update_trigger_a_table_unregister'),
        'Update trigger still exists';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='hafd.truncate_trigger_a_table_unregister'),
        'Truncate trigger still exists';

    -- Trigger functions should be gone
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='on_insert_a_table_unregister'),
        'Trigger function on_insert still exists';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='on_delete_a_table_unregister'),
        'Trigger function on_delete still exists';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='on_update_a_table_unregister'),
        'Trigger function on_update still exists';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='on_truncate_a_table_unregister'),
        'Trigger function on_truncate still exists';

    -- Table should be removed from the registered_tables array
    ASSERT NOT EXISTS (
        SELECT 1 FROM hafd.applications_transactions_register
        WHERE name='context_unregister'
          AND 'a.table_unregister' = ANY(registered_tables)
    ), 'Table still listed in registered_tables after unregister';

    -- Second call should not fail (only INFO message expected)
    PERFORM hive.app_transaction_table_unregister('context_unregister', 'a', 'table_unregister');
END;
$BODY$;
