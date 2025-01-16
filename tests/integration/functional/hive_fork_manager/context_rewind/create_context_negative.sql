CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    BEGIN
        PERFORM hive.context_create( '*my_context', 'a' );
        ASSERT FALSE, 'Cannot catch expected exception: *my_context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.context_create( 'my context', 'a' );
        ASSERT FALSE, 'Cannot catch expected exception: my context';
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
    ASSERT NOT EXISTS ( SELECT * FROM hafd.contexts ), 'Some context were created';
END
$BODY$
;




