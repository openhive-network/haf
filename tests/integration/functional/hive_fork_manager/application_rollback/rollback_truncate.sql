CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    CREATE SCHEMA b;

    PERFORM hive.app_create_context( _name =>'context', _schema => 'a', _is_forking => false );

    CREATE TABLE b.table1(
                             id   INTEGER NOT NULL,
                             smth TEXT NOT NULL,
                             hive_rowid BIGINT
    );

    PERFORM hive.app_transaction_table_register('b', 'table1', 'context');

    UPDATE hafd.applications_transactions_register SET current_app_tx_id = 1;
    INSERT INTO b.table1(id, smth) VALUES (123, 'blabla');

    TRUNCATE hafd.shadow_b_table1;
    UPDATE hafd.applications_transactions_register SET current_app_tx_id = 2;
    TRUNCATE b.table1;
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM hive.app_transaction_rollback_on_table('b', 'table1', -1);
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    ASSERT (SELECT COUNT(*) FROM b.table1 WHERE id=123)=1, 'Truncated row was not reinserted';
    ASSERT (SELECT COUNT(*) FROM hafd.shadow_b_table1)=0, 'Shadow table is not empty';
END;
$BODY$;
