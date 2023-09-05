
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
    -- to check if other types of queries do not interfere
    SET query_supervisor.limit_selects TO 1;
    SET query_supervisor.limit_updates TO 1;
    SET query_supervisor.limit_inserts TO 1;

    -- by default limit is 1000
    DELETE FROM numbers;
END
$BODY$
;





