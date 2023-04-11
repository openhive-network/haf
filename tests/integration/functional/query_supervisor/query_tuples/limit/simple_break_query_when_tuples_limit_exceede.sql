DROP FUNCTION IF EXISTS haf_admin_test_error;
CREATE FUNCTION haf_admin_test_error()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM * FROM generate_series(1,10000);
END
$BODY$
;





