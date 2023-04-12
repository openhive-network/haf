DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
DECLARE
    __value TEXT;
BEGIN
    SELECT setting FROM pg_settings WHERE name='query_supervisor.limit_tuples' INTO __value;

    ASSERT __value IS NOT NULL , 'query_supervisor.limit_tuples does not exist';
    ASSERT __value = '1000' , 'Default value of query_supervisor.limit_tuples is not 1000';
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
DECLARE
    __value TEXT;
BEGIN
    SET query_supervisor.limit_tuples TO 5000;
    SELECT setting FROM pg_settings WHERE name='query_supervisor.limit_tuples' INTO __value;

    ASSERT __value = '5000' , 'query_supervisor.limited_tuples != 5000';
END
$BODY$
;






