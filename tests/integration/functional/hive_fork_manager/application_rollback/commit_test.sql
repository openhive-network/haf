CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.app_create_context( _name =>'context', _schema => 'a', _is_forking => false  );

    -- create simple application table
    CREATE TABLE a.table1(
                             id   INTEGER NOT NULL,
                             smth TEXT NOT NULL
    );

    -- register for app-managed rollback
    PERFORM hive.app_transaction_table_register('a', 'table1', 'context');

    -- start first transaction (tx_id = 1)
    UPDATE hafd.applications_transactions_register SET current_app_tx_id = 1;
    INSERT INTO a.table1(id, smth) VALUES (1, 'tx1');

    -- second transaction (tx_id = 2)
    UPDATE hafd.applications_transactions_register SET current_app_tx_id = 2;
    INSERT INTO a.table1(id, smth) VALUES (2, 'tx2');

    -- third transaction (tx_id = 3)
    UPDATE hafd.applications_transactions_register SET current_app_tx_id = 3;
    INSERT INTO a.table1(id, smth) VALUES (3, 'tx3');

    -- verify shadow table is filled
    ASSERT (SELECT COUNT(*) FROM hafd.shadow_a_table1) = 3,
        'Expected >=3 rows in shadow table before accept';
END;
$BODY$;

-- ===================================================================
-- WHEN: accept transactions up to tx_id 2
-- ===================================================================
CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_transaction_commit_on_table('a', 'table1', 2);
END;
$BODY$;

-- ===================================================================
-- THEN: only rows with tx_id > 2 remain in shadow table,
--       rollback before tx 3 is impossible
-- ===================================================================
CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __remaining_count INT;
    __remaining_tx_ids TEXT;
BEGIN
    SELECT COUNT(*) FROM hafd.shadow_a_table1 INTO __remaining_count;
    ASSERT __remaining_count = 1, 'Expected remaining shadow rows after accept';

    ASSERT EXISTS (
        SELECT 1 FROM hafd.shadow_a_table1 WHERE hive_block_num = 3
    ), 'Shadow rows with tx_id = 3 was deleted';

    ASSERT NOT EXISTS (
        SELECT 1 FROM hafd.shadow_a_table1 WHERE hive_block_num <= 2
    ), 'Shadow rows with tx_id <= 2 were not deleted';
END;
$BODY$;
