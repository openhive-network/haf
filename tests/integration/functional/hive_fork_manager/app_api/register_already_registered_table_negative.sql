DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    CREATE SCHEMA a;
    CREATE TABLE a.table1( id INT ) INHERITS( hive.context );
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
    BEGIN
    PERFORM hive.app_register_table( 'a.table1', 'context' );
    ASSERT FALSE, 'No expected exception';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
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
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='table1' AND column_name='hive_rowid' ), 'No hive.row_id column';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'shadow_a_table1' ), 'No shadow table';
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_a_table1' AND column_name='hive_block_num' AND data_type='integer' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_a_table1' AND column_name='hive_operation_type' AND udt_name='trigger_operation' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_a_table1' AND column_name='hive_operation_id' AND data_type='bigint' );
    ASSERT EXISTS ( SELECT FROM hive.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table1' AND shadow_table_name='shadow_a_table1' ), 'No entry about registered table';
END
$BODY$
;





