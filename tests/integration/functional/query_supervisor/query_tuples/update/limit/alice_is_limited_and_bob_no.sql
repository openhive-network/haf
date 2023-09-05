CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- query shall not be broken
    CREATE TABLE alice_numbers( num INT );
    INSERT INTO alice_numbers SELECT generate_series(1,1001);
END
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- query shall not be broken
    CREATE TABLE bob_numbers( num INT );
    INSERT INTO bob_numbers SELECT generate_series(1,1001);
END
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_error()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- we will update 1001 rows, default limit is 1000
    UPDATE alice_numbers SET num = 1;
END;
$BODY$
;


CREATE OR REPLACE PROCEDURE bob_test_when()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- we will update 1001 rows, default limit is 1000
    UPDATE bob_numbers SET num = 1;
END;
$BODY$
;

