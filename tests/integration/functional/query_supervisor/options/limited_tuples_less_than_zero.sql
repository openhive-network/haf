DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$

BEGIN
   -- nothing to check here
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
    BEGIN
        SET query_supervisor.limit_tuples TO -1000;
        ASSERT FALSE, 'Expected exception was not rised';
    EXCEPTION WHEN OTHERS THEN
    END;

    SELECT setting FROM pg_settings WHERE name='query_supervisor.limit_tuples' INTO __value;
    ASSERT __value = '1000' , 'query_supervisor.limited_tuples != 1000';
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





