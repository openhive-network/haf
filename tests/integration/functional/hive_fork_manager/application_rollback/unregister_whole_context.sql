-- ===================================================================
-- Test: hive.app_managed_rollback_unregister_whole_context
-- Purpose: verify that all rollback-managed tables in a context are
--          unregistered and hafd.applications_transactions_register cleaned up.
-- ===================================================================

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;

    -- Create a rollback-managed context
    PERFORM hive.app_create_context(_name => 'context_unreg_all', _schema => 'a', _is_forking => false);

    -- Create two tables and register both
    CREATE TABLE a.table_unreg1(
                                   id SERIAL PRIMARY KEY,
                                   smth INTEGER,
                                   name TEXT
    );

    CREATE TABLE a.table_unreg2(
                                   id SERIAL PRIMARY KEY,
                                   val INTEGER,
                                   description TEXT
    );

    PERFORM hive.app_transaction_table_register('a', 'table_unreg1', 'context_unreg_all');
    PERFORM hive.app_transaction_table_register('a', 'table_unreg2', 'context_unreg_all');
END;
$BODY$;

-- ===================================================================
-- WHEN: unregister the whole context
-- ===================================================================
CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_transaction_unregister_context('context_unreg_all');
END;
$BODY$;

-- ===================================================================
-- THEN: verify both tables and context were cleaned up
-- ===================================================================
CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    -- Context should be removed
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.applications_transactions_register WHERE name='context_unreg_all'),
        'Context still present in hafd.applications_transactions_register after unregistering whole context';

    -- Shadow tables should be dropped
    ASSERT NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='hafd' AND table_name='shadow_a_table_unreg1'),
        'Shadow table for table_unreg1 not dropped';
    ASSERT NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='hafd' AND table_name='shadow_a_table_unreg2'),
        'Shadow table for table_unreg2 not dropped';

    -- Triggers should be dropped
    ASSERT NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='hafd.insert_trigger_a_table_unreg1'),
        'Insert trigger for table_unreg1 still exists';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='hafd.insert_trigger_a_table_unreg2'),
        'Insert trigger for table_unreg2 still exists';

    -- Trigger functions should be dropped
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='on_insert_a_table_unreg1'),
        'Trigger function on_insert_a_table_unreg1 still exists';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='on_insert_a_table_unreg2'),
        'Trigger function on_insert_a_table_unreg2 still exists';
END;
$BODY$;
