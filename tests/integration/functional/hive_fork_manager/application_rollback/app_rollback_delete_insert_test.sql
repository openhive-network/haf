-- ===================================================================
-- Test: hive.app_managed_rollback - delete + insert
-- Purpose: verify rollback restores deleted rows and removes new inserts.
-- ===================================================================

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.app_create_context('ctx_app_rollback_delins', 'a', false);

    CREATE TABLE a.table1(id SERIAL PRIMARY KEY, val INTEGER, note TEXT);
    PERFORM hive.app_transaction_table_register('a', 'table1', 'ctx_app_rollback_delins');

    -- TX1: insert base rows
    PERFORM hive.app_transaction_begin('ctx_app_rollback_delins');
    INSERT INTO a.table1(val, note) VALUES (1, 'base'), (2, 'base'), (3, 'base');

    -- TX2: delete all
    PERFORM hive.app_transaction_begin('ctx_app_rollback_delins');
    DELETE FROM a.table1;

    -- TX3: insert new data
    PERFORM hive.app_transaction_begin('ctx_app_rollback_delins');
    INSERT INTO a.table1(val, note) VALUES (10, 'new'), (11, 'new');
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_transaction_rollback('ctx_app_rollback_delins', 1);
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE plpgsql
AS
$BODY$
DECLARE __cnt INT;
BEGIN
    SELECT COUNT(*) INTO __cnt FROM a.table1;
    ASSERT __cnt = 3, format('Expected rollback to restore 3 base rows, got %s', __cnt);
END;
$BODY$;
