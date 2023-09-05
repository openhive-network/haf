
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- query shall not be broken
    CREATE TABLE numbers( num INT );
    INSERT INTO numbers SELECT generate_series(1,1001);
END
$BODY$
;

CREATE OR REPLACE PROCEDURE bobhaf_admin_test_error()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- we will update 1001 rows, default limit is 1000
    DELETE FROM numbers;
END
$BODY$
;





