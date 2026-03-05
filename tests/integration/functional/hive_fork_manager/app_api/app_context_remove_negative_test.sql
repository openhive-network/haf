
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE a.table1( id INT ) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN

    BEGIN
        PERFORM hive.app_remove_context( 'not_existed_context' );
        ASSERT FALSE, 'Expected exception was not rised';
        EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='table1' AND column_name='hive_rowid' ), 'hive_rowid column should not exist';
    ASSERT NOT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name  = 'shadow_a_table1' ), 'shadow table should not exist';
    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hafd.insert_trigger_a_table1'), 'Insert trigger should not exist';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_insert_a_table1'), 'Insert trigger function should not exist';
    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hafd.delete_trigger_a_table1' ), 'Delete trigger should not exist';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_delete_a_table1') ,'Delete trigger function should not exist';
    ASSERT NOT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hafd.update_trigger_a_table1' ), 'Update trigger should not exist';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_update_a_table1'), 'Update trigger function should not exist';
    ASSERT NOT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_truncate_a_table1'), 'Truncate trigger function should not exist';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name  = 'context' ), 'Context base table exists';
END;
$BODY$
;





