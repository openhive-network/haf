-- ===================================================================
-- Test: hive.app_managed_rollback - update some rows
-- Purpose: verify rollback restores only affected rows, leaving newer ones.
-- ===================================================================

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.app_create_context('ctx_app_rollback_updsome', 'a', false);

    CREATE TABLE a.table1(id SERIAL PRIMARY KEY, val INTEGER, note TEXT);
    PERFORM hive.app_transaction_table_register('a', 'table1', 'ctx_app_rollback_updsome');

    -- TX1: insert rows
    PERFORM hive.app_transaction_begin('ctx_app_rollback_updsome');
    INSERT INTO a.table1(val, note) VALUES (1, 'base'), (2, 'base'), (3, 'base');

    -- TX2: update one row
    PERFORM hive.app_transaction_begin('ctx_app_rollback_updsome');
    UPDATE a.table1 SET note='upd' WHERE val=2;

    -- TX3: insert another new row
    PERFORM hive.app_transaction_begin('ctx_app_rollback_updsome');
    INSERT INTO a.table1(val, note) VALUES (10, 'new');
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_transaction_rollback('ctx_app_rollback_updsome', 1);
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE plpgsql
AS
$BODY$
DECLARE __cnt INT;
BEGIN
    SELECT COUNT(*) INTO __cnt FROM a.table1;
    ASSERT __cnt = 3, format('Expected rollback to restore 3 base rows only, got %s', __cnt);
END;
$BODY$;
