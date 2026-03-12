
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.connect( 'test', 0, 0, 0, TRUE, TRUE );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.context_create( 'ctx', 'a' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Context table should exist without hive_rowid
    ASSERT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='ctx'), 'Context table not created';
    ASSERT NOT EXISTS (SELECT FROM information_schema.columns WHERE table_schema='a' AND table_name='ctx' AND column_name='hive_rowid'), 'hive_rowid should not exist in lite schema';

    -- Context row should exist in hafd.contexts
    ASSERT EXISTS (SELECT FROM hafd.contexts WHERE name='ctx'), 'Context row not found';

    -- Forking columns should still exist (kept for compatibility) but context should be non-forking
    ASSERT EXISTS (SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='contexts' AND column_name='is_forking'), 'is_forking column should exist';
    ASSERT ( SELECT is_forking FROM hafd.contexts WHERE name='ctx' ) = FALSE, 'Context should be non-forking in lite mode';
END;
$BODY$
;
