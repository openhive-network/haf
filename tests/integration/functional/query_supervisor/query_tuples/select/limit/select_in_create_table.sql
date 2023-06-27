-- test for an issue: https://gitlab.syncad.com/hive/haf/-/issues/143

-- Bob is not limited, so he can insert a lot of tuples
DROP FUNCTION IF EXISTS bob_test_given;
CREATE FUNCTION bob_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- query shall not be broken
    CREATE TABLE numbers( num INT );
    INSERT INTO numbers SELECT generate_series(1,10000);
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
    CREATE TABLE test AS SELECT * FROM  numbers;
END
$BODY$
;
