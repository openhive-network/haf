CREATE OR REPLACE PROCEDURE haf_admin_test_error()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM * FROM generate_series(1,10000);
END
$BODY$
;





