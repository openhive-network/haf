DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context' );
    CREATE TABLE A.table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( hive.context );
    CREATE TABLE table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( hive.context );
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    DROP TABLE A.table1;
END
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive_insert_trigger_a_table1' ), 'Insert trigger not cleaned';
    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_insert_trigger_a_table1'), 'Insert trigger not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_insert_a_table1'), 'Insert trigger function not dropped';

    ASSERT NOT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive_delete_trigger_a_table1' ), 'Delete trigger not cleaned';
    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_delete_trigger_a_table1' ), 'Delete trigger not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_delete_a_table1') ,'Delete trigger function not dropped';

    ASSERT NOT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive_update_trigger_a_table1' ), 'Update trigger not cleaned';
    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_update_trigger_a_table1' ), 'Update trigger not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_update_a_table1'), 'Update trigger function not dropped';

    ASSERT NOT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive_truncate_trigger_a_table1' ), 'Truncate trigger not cleaned';
    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_truncate_trigger_a_table1' ), 'Truncate trigger not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_truncate_a_table1'), 'Truncate trigger function not dropped';

    ASSERT NOT EXISTS ( SELECT * FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'shadow_a_table1' ), 'Shadow table was not dropped';

    ASSERT NOT EXISTS ( SELECT * FROM hive.registered_tables WHERE origin_table_schema='A' AND origin_table_name='table1' ), 'Entry in registered_tables was not deleted';
END
$BODY$
;




