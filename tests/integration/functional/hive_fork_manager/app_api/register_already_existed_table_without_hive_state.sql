CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- the state of a database to which hived has never connected
    DELETE FROM hafd.hive_state;

    CREATE SCHEMA a;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE a.table1( id INT );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_register_table( 'a', 'table1', 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT hive.is_lite_schema() IS FALSE, 'is_lite_schema is not FALSE';
    ASSERT hive.is_lite_mode() IS FALSE, 'is_lite_mode is not FALSE';
    ASSERT hive.is_pruning_enabled() IS FALSE, 'is_pruning_enabled is not FALSE';
    ASSERT hive.app_get_irreversible_block() = 0, 'app_get_irreversible_block is not 0';

    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='a' AND table_name='table1' AND column_name='hive_rowid' ), 'No hive.row_id column';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name  = 'shadow_a_table1' ), 'No shadow table';
    ASSERT EXISTS ( SELECT FROM hafd.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table1' AND shadow_table_name='shadow_a_table1' ), 'No entry about registered table';
END
$BODY$
;
