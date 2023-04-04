DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
DECLARE
    __value TEXT;
BEGIN
    SELECT setting FROM pg_settings WHERE name='query_supervisor.limited_users' INTO __value;

    ASSERT __value IS NOT NULL , 'query_supervisor.limited_users does not exist';
    ASSERT __value = '' , 'Default value of query_supervisor.limited_users is not an empty list';
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
DECLARE
    __value TEXT;
BEGIN
    SET query_supervisor.limited_users TO 'alice';
    SELECT setting FROM pg_settings WHERE name='query_supervisor.limited_users' INTO __value;

    ASSERT __value = 'alice' , 'query_supervisor.limited_users != alice';
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





