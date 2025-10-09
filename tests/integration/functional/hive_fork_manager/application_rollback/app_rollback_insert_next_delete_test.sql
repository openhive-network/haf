-- ===================================================================
-- Test: hive.app_managed_rollback - insert next + delete
-- Purpose: verify rollback after delete restores both original and next inserted rows.
-- ===================================================================

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.app_create_context('ctx_app_rollback_next', 'a', false);

    CREATE TABLE a.table1(id SERIAL PRIMARY KEY, val INTEGER, note TEXT);
    PERFORM hive.app_transaction_table_register('a', 'table1', 'ctx_app_rollback_next');

    -- TX1: insert 3 rows
    PERFORM hive.app_transaction_begin('ctx_app_rollback_next');
    INSERT INTO a.table1(val, note) VALUES (1, 'tx1'), (2, 'tx1'), (3, 'tx1');

    -- TX2: insert 2 new rows
    PERFORM hive.app_transaction_begin('ctx_app_rollback_next');
    INSERT INTO a.table1(val, note) VALUES (4, 'tx2'), (5, 'tx2');

    -- TX3: delete all
    PERFORM hive.app_transaction_begin('ctx_app_rollback_next');
    DELETE FROM a.table1;
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_transaction_rollback('ctx_app_rollback_next', 2);
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE plpgsql
AS
$BODY$
DECLARE __cnt INT;
BEGIN
    SELECT COUNT(*) INTO __cnt FROM a.table1;
    ASSERT __cnt = 5, format('Expected 5 rows after rollback, got %s', __cnt);
END;
$BODY$;
