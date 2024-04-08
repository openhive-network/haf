
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    PERFORM hive.context_create( _name =>'context_nf', _is_forking => false );
    CREATE SCHEMA a;
    CREATE TABLE a.table1( id INT );
    CREATE TABLE a.table2( id INT );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_register_table( 'a', 'table1', 'context' );
    PERFORM hive.app_register_table( 'a', 'table2', 'context_nf' );
    --ALTER TABLE a.table1 ADD COLUMN hive_rowid BIGINT NOT NULL;
    --ALTER TABLE a.table1 INHERIT hive.context;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='table1' AND column_name='hive_rowid' ), 'No hive.row_id column';
    ASSERT NOT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='table2' AND column_name='hive_rowid' ), 'hive.row_id column for non forking context';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'shadow_a_table1' ), 'No shadow table';
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_a_table1' AND column_name='hive_block_num' AND data_type='integer' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_a_table1' AND column_name='hive_operation_type' AND udt_name='trigger_operation' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_a_table1' AND column_name='hive_operation_id' AND data_type='bigint' );
    ASSERT EXISTS ( SELECT FROM hive.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table1' AND shadow_table_name='shadow_a_table1' ), 'No entry about registered table';
END
$BODY$
;





