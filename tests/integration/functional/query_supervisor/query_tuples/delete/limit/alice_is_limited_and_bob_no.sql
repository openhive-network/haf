DROP FUNCTION IF EXISTS alice_test_given;
CREATE FUNCTION alice_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- query shall not be broken
    CREATE TABLE alice_numbers( num INT );
    INSERT INTO alice_numbers SELECT generate_series(1,1001);
END
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_given;
CREATE FUNCTION bob_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- query shall not be broken
    CREATE TABLE bob_numbers( num INT );
    INSERT INTO bob_numbers SELECT generate_series(1,1001);
END
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_error;
CREATE FUNCTION alice_test_error()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- we will delet 1001 rows, default limit is 1000
    DELETE FROM alice_numbers;
END;
$BODY$
;


DROP FUNCTION IF EXISTS bob_test_when;
CREATE FUNCTION bob_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- we will delete 1001 rows, default limit is 1000
    DELETE FROM bob_numbers;
END;
$BODY$
;
