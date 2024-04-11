CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- query shall not be broken
    CREATE SCHEMA alice;
    CREATE TABLE alice.alice_numbers( num INT );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- query shall not be broken
    CREATE SCHEMA bob;
    CREATE TABLE bob.bob_numbers( num INT );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_error()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- we will update 1001 rows, default limit is 1000
    INSERT INTO alice.alice_numbers SELECT generate_series(1,1001);
END;
$BODY$
;


CREATE OR REPLACE PROCEDURE bob_test_when()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- we will update 1001 rows, default limit is 1000
    INSERT INTO bob.bob_numbers SELECT generate_series(1,1001);
END;
$BODY$
;

