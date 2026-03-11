
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
    CREATE TABLE a.t1(id SERIAL PRIMARY KEY DEFERRABLE, val TEXT) INHERITS( a.ctx );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.unregister_table( 'a', 't1' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Table should be unregistered
    ASSERT NOT EXISTS (SELECT FROM hafd.registered_tables WHERE origin_table_schema='a' AND origin_table_name='t1'), 'Table should be unregistered';

    -- Table itself should still exist
    ASSERT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='t1'), 'Table should still exist after unregister';

    -- Table should no longer inherit from context base table
    ASSERT NOT EXISTS (
        SELECT FROM pg_inherits
        JOIN pg_class child ON pg_inherits.inhrelid = child.oid
        JOIN pg_namespace child_ns ON child.relnamespace = child_ns.oid
        JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
        JOIN pg_namespace parent_ns ON parent.relnamespace = parent_ns.oid
        WHERE child_ns.nspname = 'a' AND child.relname = 't1'
          AND parent_ns.nspname = 'a' AND parent.relname = 'ctx'
    ), 'Table should no longer inherit from context base table';
END;
$BODY$
;
