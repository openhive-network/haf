-- ===================================================================
-- Test: hive.app_managed_transaction_start
-- Purpose: verify that starting an application transaction increments
--          and returns the new current_app_tx_id for the given context.
-- ===================================================================

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.app_create_context( _name =>'context', _schema => 'a', _is_forking => false );

    CREATE TABLE a.table1(
                             id   INTEGER NOT NULL,
                             smth TEXT NOT NULL,
                             hive_rowid BIGINT
    );

    PERFORM hive.app_transaction_table_register('a', 'table1', 'context');
END;
$BODY$;

-- ===================================================================
-- WHEN: start a new transaction for the given context
-- ===================================================================
CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __returned_tx_id INTEGER;
BEGIN
    __returned_tx_id := hive.app_transaction_begin('context');
    ASSERT __returned_tx_id IS NOT NULL, 'returned tx_id should not be null';
    ASSERT __returned_tx_id = 1, format('Expected returned tx_id = 1, got %s', __returned_tx_id);

    __returned_tx_id := hive.app_transaction_begin('context');
    ASSERT __returned_tx_id IS NOT NULL, 'returned tx_id should not be null';
    ASSERT __returned_tx_id = 2, format('Expected returned tx_id = 2, got %s', __returned_tx_id);
END;
$BODY$;

