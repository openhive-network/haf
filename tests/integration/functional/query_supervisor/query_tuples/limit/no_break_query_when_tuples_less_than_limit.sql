DROP FUNCTION IF EXISTS test_error;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- by default limit is 1000
    PERFORM * FROM generate_series(1,500);
END
$BODY$
;





