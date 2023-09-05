CREATE OR REPLACE PROCEDURE alice_test_error()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    ALTER ROLE alice SET query_supervisor.limited_users TO 'bob';
END;
$BODY$
;