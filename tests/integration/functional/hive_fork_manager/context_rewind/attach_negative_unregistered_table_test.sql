CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        PERFORM hive.attach_table( 'public', 'notregisteredtable', 1 );
    EXCEPTION WHEN OTHERS THEN
        RETURN;
    END;

    ASSERT FALSE, 'Did not catch expected exception';
END
$BODY$
;





