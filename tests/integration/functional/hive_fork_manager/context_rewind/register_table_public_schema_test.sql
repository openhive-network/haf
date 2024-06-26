﻿
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

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'shadow_public_table1' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_public_table1' AND column_name='hive_block_num' AND data_type='integer' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_public_table1' AND column_name='hive_operation_type' AND udt_name='trigger_operation' );
    ASSERT EXISTS ( SELECT FROM hive.registered_tables WHERE origin_table_schema='public' AND origin_table_name='table1' AND shadow_table_name='shadow_public_table1' );

    -- triggers
    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.insert_trigger_public_table1' AND function_name='hive.on_insert_public_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.insert_trigger_public_table1');
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_insert_public_table1');

    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.delete_trigger_public_table1' AND function_name='hive.on_delete_public_table1'  );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.delete_trigger_public_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_delete_public_table1');

    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.update_trigger_public_table1' AND function_name='hive.on_update_public_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.update_trigger_public_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_update_public_table1');

    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive.truncate_trigger_public_table1' AND function_name='hive.on_truncate_public_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.truncate_trigger_public_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_truncate_public_table1');
END
$BODY$
;




