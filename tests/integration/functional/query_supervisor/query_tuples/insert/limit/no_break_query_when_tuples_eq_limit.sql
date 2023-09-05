
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- query shall not be broken
    CREATE TABLE numbers( num INT );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- to check if other types of queries do not interfere
    -- we can set because haf_admin is a superuser
    SET query_supervisor.limit_updates TO 1;
    SET query_supervisor.limit_deletes TO 1;

    -- by default limit is 1000
    INSERT INTO numbers SELECT generate_series(1,1000);
END
$BODY$
;





