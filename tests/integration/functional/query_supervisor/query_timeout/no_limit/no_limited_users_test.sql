DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
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
CREATE FUNCTION haf_admin_test_when()
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
CREATE FUNCTION haf_admin_test_then()
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





