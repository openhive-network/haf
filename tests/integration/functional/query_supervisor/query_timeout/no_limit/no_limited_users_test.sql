DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- NOTHING TO SET HERE, BY THE DEFAULT 'query_supervisor.limited_users' is an empty list
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
    PERFORM pg_sleep( 5 );
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
    --NOTHING TO CHECK HERE
END
$BODY$
;





