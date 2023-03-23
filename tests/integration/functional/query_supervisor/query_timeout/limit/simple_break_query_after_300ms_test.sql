DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    ALTER ROLE haf_admin SET local_preload_libraries TO 'libquery_supervisor.so';
    ALTER ROLE alice SET local_preload_libraries TO 'libquery_supervtisor.so';
    ALTER ROLE alice SET query_supervisor.limited_users TO 'alice';
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





