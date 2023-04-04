DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- nothing to prepare here
END
$BODY$
;

DROP FUNCTION IF EXISTS test_error;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- by default limit is 1000
    PERFORM * FROM generate_series(1,999);
END
$BODY$
;

DROP FUNCTION IF EXISTS test_error;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN

END
$BODY$
;





