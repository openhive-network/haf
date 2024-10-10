
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE A.table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( a.context );
    CREATE TABLE table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    DROP TABLE A.table1;
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT FROM hive_data.triggers WHERE trigger_name='hive_data.insert_trigger_a_table1' ), 'Insert trigger not cleaned';
    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_data.insert_trigger_a_table1'), 'Insert trigger not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_insert_a_table1'), 'Insert trigger function not dropped';

    ASSERT NOT EXISTS ( SELECT FROM hive_data.triggers WHERE trigger_name='hive_data.delete_trigger_a_table1' ), 'Delete trigger not cleaned';
    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_data.delete_trigger_a_table1' ), 'Delete trigger not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_delete_a_table1') ,'Delete trigger function not dropped';

    ASSERT NOT EXISTS ( SELECT FROM hive_data.triggers WHERE trigger_name='hive_data.update_trigger_a_table1' ), 'Update trigger not cleaned';
    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_data.update_trigger_a_table1' ), 'Update trigger not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_update_a_table1'), 'Update trigger function not dropped';

    ASSERT NOT EXISTS ( SELECT FROM hive_data.triggers WHERE trigger_name='hive_data.truncate_trigger_a_table1' ), 'Truncate trigger not cleaned';
    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_data.truncate_trigger_a_table1' ), 'Truncate trigger not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_truncate_a_table1'), 'Truncate trigger function not dropped';

    ASSERT NOT EXISTS ( SELECT * FROM information_schema.tables WHERE table_schema='hive_data' AND table_name  = 'shadow_a_table1' ), 'Shadow table was not dropped';

    ASSERT NOT EXISTS ( SELECT * FROM hive_data.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table1' ), 'Entry in registered_tables was not deleted';
END
$BODY$
;




