CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( _name => 'context', _is_forking => FALSE, _schema => 'a' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE TABLE A.table1(id  SERIAL PRIMARY KEY DEFERRABLE, smth INTEGER, name TEXT) INHERITS( a.context );

    -- tables which shall not be registered
    CREATE TABLE A.table_base( id INT );
    CREATE TABLE A.table_child( id2 INT ) INHERITS( A.table_base );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='table1' AND column_name='hive_rowid' );

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name  = 'shadow_a_table1' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='shadow_a_table1' AND column_name='hive_block_num' AND data_type='integer' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='shadow_a_table1' AND column_name='hive_operation_type' AND udt_name='trigger_operation' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='shadow_a_table1' AND column_name='hive_operation_id' AND data_type='bigint' );
    ASSERT EXISTS ( SELECT FROM hafd.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table1' AND shadow_table_name='shadow_a_table1' );

    ASSERT NOT EXISTS ( SELECT FROM hafd.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table_child' ), 'Table shall not be registerd';
    ASSERT NOT EXISTS ( SELECT FROM hafd.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table_base' ), 'Table shall not be registerd';

    ---- triggers
    ASSERT EXISTS ( SELECT FROM hafd.triggers WHERE trigger_name='hafd.insert_trigger_a_table1' AND function_name='hafd.on_insert_a_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hafd.insert_trigger_a_table1');
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_insert_a_table1');

    ASSERT EXISTS ( SELECT FROM hafd.triggers WHERE trigger_name='hafd.delete_trigger_a_table1' AND function_name='hafd.on_delete_a_table1'  );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hafd.delete_trigger_a_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_delete_a_table1');
--
    ASSERT EXISTS ( SELECT FROM hafd.triggers WHERE trigger_name='hafd.update_trigger_a_table1' AND function_name='hafd.on_update_a_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hafd.update_trigger_a_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_update_a_table1');
--
    ASSERT EXISTS ( SELECT FROM hafd.triggers WHERE trigger_name='hafd.truncate_trigger_a_table1' AND function_name='hafd.on_truncate_a_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hafd.truncate_trigger_a_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_truncate_a_table1');

    ASSERT NOT EXISTS (SELECT 0 FROM pg_class where relname = 'idx_a_table1_row_id' ), 'Index exists for table a.table1 rowid';
END
$BODY$
;




