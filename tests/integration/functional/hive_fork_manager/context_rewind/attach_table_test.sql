
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context' );
    CREATE TABLE A.table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( hive.context );
    PERFORM hive.context_detach( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.attach_table( 'A'::TEXT, 'table1'::TEXT, 1 );
    PERFORM hive.context_next_block( 'context' );
    INSERT INTO A.table1( smth, name ) VALUES (1, 'abc' );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.insert_trigger_a_table1' ), 'Insert trigger not cleaned';
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.insert_trigger_a_table1'), 'Insert trigger dropped';
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_insert_a_table1'), 'Insert trigger function dropped';

    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.delete_trigger_a_table1' ), 'Delete trigger not cleaned';
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.delete_trigger_a_table1' ), 'Delete trigger dropped';
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_delete_a_table1') ,'Delete trigger function dropped';

    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.update_trigger_a_table1' ), 'Update trigger not cleaned';
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.update_trigger_a_table1' ), 'Update trigger dropped';
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_update_a_table1'), 'Update trigger function dropped';

    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.truncate_trigger_a_table1' ), 'Truncate trigger not cleaned';
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.truncate_trigger_a_table1' ), 'Truncate trigger not dropped';
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_truncate_a_table1'), 'Truncate trigger dropped';

    ASSERT EXISTS ( SELECT * FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'shadow_a_table1' ), 'Shadow table was not dropped';
    ASSERT EXISTS ( SELECT * FROM hive.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table1' ), 'Entry in registered_tables was not deleted';

    ASSERT EXISTS ( SELECT * FROM hive.shadow_a_table1 ), 'Trigger did not isert something into shadow table';
END
$BODY$
;




