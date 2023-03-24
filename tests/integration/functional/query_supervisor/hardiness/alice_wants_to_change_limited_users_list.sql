DROP FUNCTION IF EXISTS alice_test_error;
CREATE FUNCTION alice_test_error()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    ALTER ROLE alice SET query_supervisor.limited_users TO 'bob';
END;
$BODY$
;