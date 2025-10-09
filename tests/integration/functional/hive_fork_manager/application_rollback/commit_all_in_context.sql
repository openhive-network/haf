-- ===================================================================
-- Test: hive.app_managed_transactions_commit
-- Purpose: verify that committing transactions clears shadow tables
--          for all registered tables in a context (using real inserts).
-- ===================================================================

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;

    -- Create a rollback-managed context
    PERFORM hive.app_create_context(_name => 'context_commit', _schema => 'a', _is_forking => false);

    -- Create two rollback-managed tables
    CREATE TABLE a.table_commit1(
                                    id SERIAL PRIMARY KEY,
                                    smth INTEGER,
                                    name TEXT
    );

    CREATE TABLE a.table_commit2(
                                    id SERIAL PRIMARY KEY,
                                    val INTEGER,
                                    note TEXT
    );

    -- Register both tables for rollback tracking
    PERFORM hive.app_transaction_table_register('a', 'table_commit1', 'context_commit');
    PERFORM hive.app_transaction_table_register('a', 'table_commit2', 'context_commit');

    -- start transactions and perform inserts normally
    PERFORM hive.app_transaction_begin('context_commit'); -- tx 1
    INSERT INTO a.table_commit1(smth, name) VALUES (10, 'tx1');
    INSERT INTO a.table_commit2(val, note) VALUES (20, 'tx1');

    PERFORM hive.app_transaction_begin('context_commit'); -- tx 2
    INSERT INTO a.table_commit1(smth, name) VALUES (11, 'tx2');
    INSERT INTO a.table_commit2(val, note) VALUES (21, 'tx2');

    PERFORM hive.app_transaction_begin('context_commit'); -- tx 3
    INSERT INTO a.table_commit1(smth, name) VALUES (12, 'tx3');
    INSERT INTO a.table_commit2(val, note) VALUES (22, 'tx3');

    PERFORM hive.app_transaction_begin('context_commit'); -- tx 4
    INSERT INTO a.table_commit1(smth, name) VALUES (13, 'tx4');
    INSERT INTO a.table_commit2(val, note) VALUES (23, 'tx4');

    PERFORM hive.app_transaction_begin('context_commit'); -- tx 5
    INSERT INTO a.table_commit1(smth, name) VALUES (14, 'tx5');
    INSERT INTO a.table_commit2(val, note) VALUES (24, 'tx5');
END;
$BODY$;

-- ===================================================================
-- WHEN: commit all transactions up to tx_id = 3
-- ===================================================================
CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_transaction_commit('context_commit', 3);
END;
$BODY$;

-- ===================================================================
-- THEN: verify that committed transactions were removed from shadow tables
-- ===================================================================
CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __remaining1 INT;
    __remaining2 INT;
BEGIN
    -- All shadow rows with tx <= 3 should be gone
    SELECT COUNT(*) INTO __remaining1
    FROM hafd.shadow_a_table_commit1
    WHERE hive_operation_id <= 3;
    SELECT COUNT(*) INTO __remaining2
    FROM hafd.shadow_a_table_commit2
    WHERE hive_operation_id <= 3;

    ASSERT __remaining1 = 0, format('Expected no shadow rows <= 3 in table_commit1, found %s', __remaining1);
    ASSERT __remaining2 = 0, format('Expected no shadow rows <= 3 in table_commit2, found %s', __remaining2);

    -- Entries for tx 4 and 5 should still exist
    ASSERT EXISTS (
        SELECT 1 FROM hafd.shadow_a_table_commit1 WHERE hive_operation_id > 3
    ), 'Expected uncommitted shadow rows in table_commit1 to remain';
    ASSERT EXISTS (
        SELECT 1 FROM hafd.shadow_a_table_commit2 WHERE hive_operation_id > 3
    ), 'Expected uncommitted shadow rows in table_commit2 to remain';
END;
$BODY$;
