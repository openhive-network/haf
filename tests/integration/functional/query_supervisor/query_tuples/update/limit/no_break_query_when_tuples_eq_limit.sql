
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- query shall not be broken
    CREATE TABLE numbers( num INT );
    INSERT INTO numbers SELECT generate_series(1,1000);
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- by default limit is 1000
    -- to check if other types of queries do not interfere
    -- we can set because haf_admin is a superuser
    SET query_supervisor.limit_selects TO 1;
    SET query_supervisor.limit_deletes TO 1;
    SET query_supervisor.limit_inserts TO 1;

    UPDATE numbers SET num = 1;
END
$BODY$
;





