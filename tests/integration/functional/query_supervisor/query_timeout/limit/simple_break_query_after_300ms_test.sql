DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- haf_admin is limited in the fixture
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





