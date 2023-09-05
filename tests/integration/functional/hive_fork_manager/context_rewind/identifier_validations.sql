CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context' );
END;
$BODY$
;


CREATE OR REPLACE PROCEDURE alice_test_then()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    BEGIN
        CREATE TABLE A.very_very_long_named_table_to_register_into_context_context(
            id  SERIAL PRIMARY KEY DEFERRABLE, smth INTEGER, name TEXT)
        INHERITS( hive.context );
        ASSERT FALSE, 'No expected exception';
    EXCEPTION WHEN OTHERS THEN
    END;
END
$BODY$
;




