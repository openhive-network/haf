DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
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

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.attach_table( 'A'::TEXT, 'table1'::TEXT, 1 );
    PERFORM hive.context_next_block( 'context' );
    INSERT INTO A.table1( smth, name ) VALUES (1, 'abc' );
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.hive_insert_trigger_a_table1' ), 'Insert trigger not cleaned';
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.hive_insert_trigger_a_table1'), 'Insert trigger dropped';
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_insert_a_table1'), 'Insert trigger function dropped';

    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.hive_delete_trigger_a_table1' ), 'Delete trigger not cleaned';
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.hive_delete_trigger_a_table1' ), 'Delete trigger dropped';
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_delete_a_table1') ,'Delete trigger function dropped';

    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.hive_update_trigger_a_table1' ), 'Update trigger not cleaned';
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.hive_update_trigger_a_table1' ), 'Update trigger dropped';
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_update_a_table1'), 'Update trigger function dropped';

    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.hive_truncate_trigger_a_table1' ), 'Truncate trigger not cleaned';
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.hive_truncate_trigger_a_table1' ), 'Truncate trigger not dropped';
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_truncate_a_table1'), 'Truncate trigger dropped';

    ASSERT EXISTS ( SELECT * FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'shadow_a_table1' ), 'Shadow table was not dropped';
    ASSERT EXISTS ( SELECT * FROM hive.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table1' ), 'Entry in registered_tables was not deleted';

    ASSERT EXISTS ( SELECT * FROM hive.shadow_a_table1 ), 'Trigger did not isert something into shadow table';
END
$BODY$
;




