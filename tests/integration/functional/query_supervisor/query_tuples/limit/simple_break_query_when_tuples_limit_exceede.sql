DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    ALTER ROLE haf_admin SET local_preload_libraries TO 'libquery_supervisor.so';
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
    PERFORM * FROM generate_series(1,10000);
END
$BODY$
;





