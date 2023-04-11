DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    EXECUTE  format( 'ALTER ROLE alice IN DATABASE %s SET query_supervisor.limit_timeout TO ''0'''
        , current_database()
    );
END
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_error;
CREATE FUNCTION alice_test_error()
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





