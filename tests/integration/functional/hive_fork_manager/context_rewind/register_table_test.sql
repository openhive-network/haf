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
    CREATE TABLE A.table1(id  SERIAL PRIMARY KEY DEFERRABLE, smth INTEGER, name TEXT) INHERITS( hive.context );

    -- tables which shall not be registered
    CREATE TABLE A.table_base( id INT );
    CREATE TABLE A.table_child( id2 INT ) INHERITS( A.table_base );
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
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='table1' AND column_name='hive_rowid' );

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'shadow_a_table1' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_a_table1' AND column_name='hive_block_num' AND data_type='integer' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_a_table1' AND column_name='hive_operation_type' AND udt_name='trigger_operation' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_a_table1' AND column_name='hive_operation_id' AND data_type='bigint' );
    ASSERT EXISTS ( SELECT FROM hive.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table1' AND shadow_table_name='shadow_a_table1' );

    ASSERT NOT EXISTS ( SELECT FROM hive.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table_child' ), 'Table shall not be registerd';
    ASSERT NOT EXISTS ( SELECT FROM hive.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table_base' ), 'Table shall not be registerd';

    ---- triggers
    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.hive_insert_trigger_a_table1' AND function_name='hive.hive_on_table_trigger_insert_a_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.hive_insert_trigger_a_table1');
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_insert_a_table1');

    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.hive_delete_trigger_a_table1' AND function_name='hive.hive_on_table_trigger_delete_a_table1'  );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.hive_delete_trigger_a_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_delete_a_table1');
--
    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.hive_update_trigger_a_table1' AND function_name='hive.hive_on_table_trigger_update_a_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.hive_update_trigger_a_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_update_a_table1');
--
    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.hive_truncate_trigger_a_table1' AND function_name='hive.hive_on_table_trigger_truncate_a_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.hive_truncate_trigger_a_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_truncate_a_table1');
END
$BODY$
;




