DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- query shall not be broken
    CREATE TABLE numbers( num INT );
    INSERT INTO numbers SELECT generate_series(1,1001);
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_error;
CREATE FUNCTION haf_admin_test_error()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- we will update 1001 rows, default limit is 1000
    DELETE FROM numbers;
END
$BODY$
;





