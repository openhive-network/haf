-- ===================================================================
-- Test: hive.app_managed_rollback - insert + delete
-- Purpose: verify rollback restores deleted rows inserted in earlier tx.
-- ===================================================================

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.app_create_context('ctx_app_rollback', 'a', false);

    CREATE TABLE a.table1(id SERIAL PRIMARY KEY, val INTEGER, note TEXT);
    PERFORM hive.app_transaction_table_register('a', 'table1', 'ctx_app_rollback');

    -- TX1: insert
    PERFORM hive.app_transaction_begin('ctx_app_rollback');
    INSERT INTO a.table1(val, note) VALUES (1, 'tx1'), (2, 'tx1'), (3, 'tx1');

    -- TX2: delete
    PERFORM hive.app_transaction_begin('ctx_app_rollback');
    DELETE FROM a.table1 WHERE id IN (1,2);
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_transaction_rollback('ctx_app_rollback', 1);
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE plpgsql
AS
$BODY$
DECLARE __cnt INT;
BEGIN
    SELECT COUNT(*) INTO __cnt FROM a.table1;
    ASSERT __cnt = 3, format('Expected 3 rows after rollback, got %s', __cnt);
END;
$BODY$;
