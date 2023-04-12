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
    BEGIN
        SET query_supervisor.limit_timeout TO -1000;
        ASSERT FALSE, 'Expected exception was not rised';
    EXCEPTION WHEN OTHERS THEN
    END;

    SELECT setting FROM pg_settings WHERE name='query_supervisor.limit_timeout' INTO __value;
    ASSERT __value = '300' , 'query_supervisor.limit_timeout != 300';
END
$BODY$
;






