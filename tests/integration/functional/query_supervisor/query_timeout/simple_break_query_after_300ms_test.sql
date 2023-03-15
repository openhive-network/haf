DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- Nothing to check here
END
$BODY$
;

DROP FUNCTION IF EXISTS test_error;
CREATE FUNCTION test_error()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM pg_sleep( 5 );
END
$BODY$
;





