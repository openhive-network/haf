
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE a.table1( id INT ) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_unregister_table( 'a', 'table1' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='table1' AND column_name='hive_rowid' ), 'hive.row_id column exists';

    ASSERT NOT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name  = 'shadow_a_table1' ), 'shadow table exists';
    ASSERT NOT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='shadow_a_table1' AND column_name='hive_block_num' AND data_type='integer' );

    ASSERT NOT EXISTS ( SELECT FROM hafd.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table1' AND shadow_table_name='shadow_a_table1' ), 'entry about';

    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_insert_trigger_a_table1'), 'Insert trigger not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_insert_a_table1'), 'Insert trigger function not dropped';

    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_delete_trigger_a_table1' ), 'Delete trigger not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_delete_a_table1') ,'Delete trigger function not dropped';

    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_update_trigger_a_table1' ), 'Update trigger not dropped';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_update_a_table1'), 'Update trigger function not dropped';

    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_truncate_a_table1'), 'Truncate trigger function not dropped';
END
$BODY$
;





