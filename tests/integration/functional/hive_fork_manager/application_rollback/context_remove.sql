-- ===================================================================
-- Test: hive.app_remove_context cleanup
-- Purpose: verify that removing an application context also removes
--          its triggers, shadow tables, and rollback registration rows.
-- ===================================================================

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;

    -- create a non-forking application context
    PERFORM hive.app_create_context(_name => 'context_cleanup', _schema => 'a', _is_forking => false);

    -- create and register rollback-enabled table
    CREATE TABLE a.table_cleanup(
                                    id   SERIAL PRIMARY KEY,
                                    smth INTEGER,
                                    name TEXT
    );

    PERFORM hive.app_transaction_table_register('a', 'table_cleanup', 'context_cleanup');

    -- sanity checks: table registered and shadow created
    ASSERT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='hafd' AND table_name='shadow_a_table_cleanup'),
        'Expected shadow table to exist before context removal';
    ASSERT EXISTS (SELECT 1 FROM hafd.applications_transactions_register WHERE name='context_cleanup'),
        'Expected context_cleanup row in hafd.applications_transactions_register';
END;
$BODY$;

-- ===================================================================
-- WHEN: remove the application context
-- ===================================================================
CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_remove_context('context_cleanup');
END;
$BODY$;

-- ===================================================================
-- THEN: verify all rollback structures were removed
-- ===================================================================
CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    -- Shadow table should be gone
    ASSERT NOT EXISTS (
        SELECT 1 FROM information_schema.tables WHERE table_schema='hafd' AND table_name='shadow_a_table_cleanup'
    ), 'Shadow table was not removed after context removal';

    -- All triggers should be gone
    ASSERT NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='hafd.insert_trigger_a_table_cleanup'),
        'Insert trigger still exists after context removal';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='hafd.delete_trigger_a_table_cleanup'),
        'Delete trigger still exists after context removal';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='hafd.update_trigger_a_table_cleanup'),
        'Update trigger still exists after context removal';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='hafd.truncate_trigger_a_table_cleanup'),
        'Truncate trigger still exists after context removal';

    -- Functions for triggers should be gone
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='on_insert_a_table_cleanup'),
        'Trigger function on_insert still exists';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='on_delete_a_table_cleanup'),
        'Trigger function on_delete still exists';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='on_update_a_table_cleanup'),
        'Trigger function on_update still exists';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='on_truncate_a_table_cleanup'),
        'Trigger function on_truncate still exists';

    -- Context should be removed from rollback tracking
    ASSERT NOT EXISTS (
        SELECT 1 FROM hafd.applications_transactions_register WHERE name='context_cleanup'
    ), 'Context_cleanup row still exists in hafd.applications_transactions_register after removal';
END;
$BODY$;
