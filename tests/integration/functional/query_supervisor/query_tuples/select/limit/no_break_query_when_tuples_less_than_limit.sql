CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- by default limit is 1000
    SET query_supervisor.limit_updates TO 1;
    SET query_supervisor.limit_deletes TO 1;
    SET query_supervisor.limit_inserts TO 1;

    PERFORM * FROM generate_series(1,500);
END
$BODY$
;





