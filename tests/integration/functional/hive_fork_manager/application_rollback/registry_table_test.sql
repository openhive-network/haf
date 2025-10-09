CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    CREATE SCHEMA b;

    PERFORM hive.app_create_context(_name =>'context', _schema => 'a', _is_forking => false);
    PERFORM hive.app_create_context(_name =>'context_forking', _schema => 'b', _is_forking => true);

    CREATE TABLE a.table1(
                             id  SERIAL PRIMARY KEY,
                             smth INTEGER,
                             name TEXT
    );

    CREATE TABLE b.table1(
                             id  SERIAL PRIMARY KEY,
                             smth INTEGER,
                             name TEXT
    );
END;
$BODY$;

-- ===================================================================
-- WHEN: register a.table1 in non-forking context 'context'
-- ===================================================================
CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_transaction_table_register('a', 'table1', 'context');
END;
$BODY$;

-- ===================================================================
-- ERROR CASE: attempt to register table in forking context (should fail)
-- ===================================================================
CREATE OR REPLACE PROCEDURE alice_test_error()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_transaction_table_register('b', 'table1', 'context_forking');
END;
$BODY$;

-- ===================================================================
-- THEN: verify shadow table, triggers, and array registration
-- ===================================================================
CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    -- basic schema checks
    ASSERT EXISTS (SELECT FROM information_schema.columns WHERE table_name='table1' AND column_name='hive_rowid');
    ASSERT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='shadow_a_table1');
    ASSERT EXISTS (SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='shadow_a_table1' AND column_name='hive_operation_type' AND udt_name='trigger_operation');
    ASSERT EXISTS (SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='shadow_a_table1' AND column_name='hive_operation_id' AND data_type='bigint');

    -- triggers and functions
    ASSERT EXISTS (SELECT FROM pg_trigger WHERE tgname='hafd.insert_trigger_a_table1');
    ASSERT EXISTS (SELECT FROM pg_trigger WHERE tgname='hafd.delete_trigger_a_table1');
    ASSERT EXISTS (SELECT FROM pg_trigger WHERE tgname='hafd.update_trigger_a_table1');
    ASSERT EXISTS (SELECT FROM pg_trigger WHERE tgname='hafd.truncate_trigger_a_table1');

    ASSERT EXISTS (SELECT * FROM pg_proc WHERE proname='on_insert_a_table1');
    ASSERT EXISTS (SELECT * FROM pg_proc WHERE proname='on_delete_a_table1');
    ASSERT EXISTS (SELECT * FROM pg_proc WHERE proname='on_update_a_table1');
    ASSERT EXISTS (SELECT * FROM pg_proc WHERE proname='on_truncate_a_table1');

    ASSERT EXISTS (SELECT 0 FROM pg_class WHERE relname='idx_a_table1_row_id'),
        'No index for table a.table1 rowid';

    -- ================================================================
    -- NEW CHECK: verify that 'a.table1' is listed in registered_tables
    -- ================================================================
    ASSERT EXISTS (
        SELECT 1
        FROM hafd.applications_transactions_register
        WHERE name = 'context'
          AND 'a.table1' = ANY(registered_tables)
    ), 'Expected "a.table1" to be recorded in hafd.applications_transactions_register.registered_tables array';
END;
$BODY$;
