DROP FUNCTION IF EXISTS alice_test_given;
CREATE FUNCTION alice_test_given()
RETURNS void
LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE TABLE alice_table( id INTEGER );
    INSERT INTO alice_table VALUES( 1 );
    INSERT INTO alice_table VALUES( 2 );
    INSERT INTO alice_table VALUES( 3 );
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_when;
CREATE FUNCTION alice_test_when()
RETURNS void
LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    GRANT SELECT ON alice_table TO hive_applications_group;
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_then;
CREATE FUNCTION bob_test_then()
RETURNS void
LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- check if Bob has only SELECT acces to alice_table
    ASSERT ( SELECT COUNT(*) FROM alice_table ) = 3 , 'Bob has no access to alice_table';

    BEGIN
        INSERT INTO alice_tables VALUES( 4 );
        ASSERT FALSE, 'Bob can insert to alice_table';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM alice_tables;
        ASSERT FALSE, 'Bob can delete alice_table';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        UPDATE alice_tables SET id = 4;
        ASSERT FALSE, 'Bob can update alice_table';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;
