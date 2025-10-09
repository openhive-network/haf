-- ===================================================================
-- Test: hive.app_managed_rollback - update next + delete
-- Purpose: rollback restores updated data and deleted rows.
-- ===================================================================

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.app_create_context('ctx_app_rollback_updnext', 'a', false);

    CREATE TABLE a.table1(id SERIAL PRIMARY KEY, val INTEGER, note TEXT);
    PERFORM hive.app_transaction_table_register('a', 'table1', 'ctx_app_rollback_updnext');

    -- TX1: insert base rows
    PERFORM hive.app_transaction_begin('ctx_app_rollback_updnext');
    INSERT INTO a.table1(val, note) VALUES (1, 'base'), (2, 'base'), (3, 'base');

    -- TX2: update two rows
    PERFORM hive.app_transaction_begin('ctx_app_rollback_updnext');
    UPDATE a.table1 SET note='upd' WHERE val IN (1,2);

    -- TX3: delete all
    PERFORM hive.app_transaction_begin('ctx_app_rollback_updnext');
    DELETE FROM a.table1;
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_transaction_rollback('ctx_app_rollback_updnext', 1);
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE plpgsql
AS
$BODY$
DECLARE __cnt INT;
BEGIN
    SELECT COUNT(*) INTO __cnt FROM a.table1;
    ASSERT __cnt = 3, format('Expected 3 restored base rows, got %s', __cnt);
END;
$BODY$;
