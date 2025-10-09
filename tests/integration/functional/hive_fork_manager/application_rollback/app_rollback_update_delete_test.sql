-- ===================================================================
-- Test: hive.app_managed_rollback - update + delete
-- Purpose: verify that application-managed rollback correctly restores
--          table rows after update and delete operations.
-- ===================================================================

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;

    -- Create application-managed rollback context
    PERFORM hive.app_create_context(_name => 'context_app_rollback', _schema => 'a', _is_forking => false);

    -- Create and register rollback-managed table
    CREATE TABLE a.table1(
                             id SERIAL PRIMARY KEY,
                             val INTEGER,
                             note TEXT
    );

    PERFORM hive.app_transaction_table_register('a', 'table1', 'context_app_rollback');

    -- TX 1: initial insert
    PERFORM hive.app_transaction_begin('context_app_rollback');
    INSERT INTO a.table1(val, note) VALUES (1, 'initial');
    INSERT INTO a.table1(val, note) VALUES (2, 'initial');
    INSERT INTO a.table1(val, note) VALUES (3, 'initial');

    -- TX 2: update + delete
    PERFORM hive.app_transaction_begin('context_app_rollback');
    UPDATE a.table1 SET note = 'updated' WHERE id IN (1, 2);
    DELETE FROM a.table1 WHERE id = 3;
END;
$BODY$;

-- ===================================================================
-- WHEN: rollback to transaction 1
-- ===================================================================
CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_transaction_rollback('context_app_rollback', 1);
END;
$BODY$;

-- ===================================================================
-- THEN: verify rows restored after rollback
-- ===================================================================
CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __cnt INT;
    __note TEXT;
BEGIN
    -- Verify all 3 rows are present again
    SELECT COUNT(*) INTO __cnt FROM a.table1;
    ASSERT __cnt = 3, format('Expected 3 rows after rollback, found %s', __cnt);

    -- Verify values restored to original
    SELECT DISTINCT note INTO __note FROM a.table1;
    ASSERT __note = 'initial', format('Expected all rows to have note=initial, got %s', __note);
END;
$BODY$;
