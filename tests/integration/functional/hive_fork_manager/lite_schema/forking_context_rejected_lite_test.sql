
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.connect( 'test', 0, 0, 0, TRUE, TRUE );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_error()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Attempting to create a forking context in lite mode should fail
    CREATE SCHEMA a;
    PERFORM hive.context_create( 'ctx_forking', 'a', TRUE );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- The forking context should NOT have been created
    ASSERT NOT EXISTS (SELECT FROM hafd.contexts WHERE name = 'ctx_forking'),
        'Forking context should not exist in lite mode';
END;
$BODY$
;
