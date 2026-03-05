
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
    BEGIN
    PERFORM hive.app_register_table( 'a.table1', 'context' );
    ASSERT FALSE, 'No expected exception';
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
    ASSERT EXISTS ( SELECT FROM hafd.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table1' ), 'No entry about registered table';

END
$BODY$
;





