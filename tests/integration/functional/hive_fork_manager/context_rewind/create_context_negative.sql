CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        PERFORM hive.context_create( '*my_context' );
        ASSERT FALSE, 'Cannot catch expected exception: *my_context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.context_create( 'my context' );
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
    ASSERT NOT EXISTS ( SELECT * FROM hive.contexts ), 'Some context were created';
END
$BODY$
;




