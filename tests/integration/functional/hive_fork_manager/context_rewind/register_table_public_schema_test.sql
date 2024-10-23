
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 'a' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE TABLE table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( a.context );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='table1' AND column_name='hive_rowid' );

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name  = 'shadow_public_table1' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='shadow_public_table1' AND column_name='hive_block_num' AND data_type='integer' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='shadow_public_table1' AND column_name='hive_operation_type' AND udt_name='trigger_operation' );
    ASSERT EXISTS ( SELECT FROM hafd.registered_tables WHERE origin_table_schema='public' AND origin_table_name='table1' AND shadow_table_name='shadow_public_table1' );

    -- triggers
    ASSERT EXISTS ( SELECT FROM hafd.triggers WHERE trigger_name='hafd.insert_trigger_public_table1' AND function_name='hafd.on_insert_public_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hafd.insert_trigger_public_table1');
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_insert_public_table1');

    ASSERT EXISTS ( SELECT FROM hafd.triggers WHERE trigger_name='hafd.delete_trigger_public_table1' AND function_name='hafd.on_delete_public_table1'  );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hafd.delete_trigger_public_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_delete_public_table1');

    ASSERT EXISTS ( SELECT FROM hafd.triggers WHERE trigger_name='hafd.update_trigger_public_table1' AND function_name='hafd.on_update_public_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hafd.update_trigger_public_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_update_public_table1');

    ASSERT EXISTS ( SELECT FROM hafd.triggers WHERE trigger_name='hafd.truncate_trigger_public_table1' AND function_name='hafd.on_truncate_public_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hafd.truncate_trigger_public_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_truncate_public_table1');
END
$BODY$
;




