-- test for an issue: https://gitlab.syncad.com/hive/haf/-/issues/143

-- Bob is not limited, so he can insert a lot of tuples
CREATE OR REPLACE PROCEDURE bob_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- query shall not be broken
    CREATE TABLE numbers( num INT );
    INSERT INTO numbers SELECT generate_series(1,10000);
END
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE TABLE test AS SELECT * FROM  numbers;
END
$BODY$
;
