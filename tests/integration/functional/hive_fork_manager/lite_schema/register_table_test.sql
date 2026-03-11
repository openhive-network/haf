
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.connect( 'test', 0, 0, 0, TRUE, TRUE );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.context_create( 'ctx', 'a' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE TABLE a.t1(id SERIAL PRIMARY KEY DEFERRABLE, val TEXT) INHERITS( a.ctx );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Table should be registered
    ASSERT EXISTS (SELECT FROM hafd.registered_tables WHERE origin_table_schema='a' AND origin_table_name='t1'), 'Table not registered';

    -- No shadow table in lite schema
    ASSERT NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='shadow_a_t1'), 'Shadow table should not exist in lite schema';

    -- No hive_rowid column
    ASSERT NOT EXISTS (SELECT FROM information_schema.columns WHERE table_schema='a' AND table_name='t1' AND column_name='hive_rowid'), 'hive_rowid should not exist in lite schema';

    -- No triggers registered
    ASSERT NOT EXISTS (SELECT FROM hafd.triggers WHERE trigger_name LIKE '%a_t1%'), 'No triggers should be registered in lite schema';

    -- No actual triggers on the table
    ASSERT NOT EXISTS (
        SELECT FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'a' AND c.relname = 't1' AND NOT t.tgisinternal
    ), 'No triggers should exist on table in lite schema';

    -- No rowid index
    ASSERT NOT EXISTS (SELECT FROM pg_class WHERE relname = 'idx_a_t1_row_id'), 'No rowid index should exist in lite schema';
END;
$BODY$
;
