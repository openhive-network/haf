CREATE OR REPLACE PROCEDURE alice_test_error()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    ALTER ROLE alice SET query_supervisor.limit_tuples TO '1000000';
END;
$BODY$
;