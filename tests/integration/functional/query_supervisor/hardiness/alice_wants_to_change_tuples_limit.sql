DROP FUNCTION IF EXISTS alice_test_error;
CREATE FUNCTION alice_test_error()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    ALTER ROLE alice SET query_supervisor.limit_tuples TO '1000000';
END;
$BODY$
;