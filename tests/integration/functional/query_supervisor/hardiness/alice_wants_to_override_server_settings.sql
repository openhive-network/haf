CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    BEGIN
        ALTER ROLE alice RESET shared_preload_libraries;
        ALTER ROLE alice RESET local_preload_libraries;
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_error()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM pg_sleep( 5 );
END;
$BODY$
;