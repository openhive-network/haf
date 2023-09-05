CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        PERFORM hive.context_detach( 'context' );
    EXCEPTION WHEN OTHERS THEN
        RETURN;
    END;

    ASSERT FALSE, "DID not catch expected exception";
END
$BODY$
;




