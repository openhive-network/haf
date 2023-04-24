DROP FUNCTION IF EXISTS alice_test_given;
CREATE FUNCTION alice_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
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

DROP FUNCTION IF EXISTS alice_test_error;
CREATE FUNCTION alice_test_error()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM pg_sleep( 5 );
END;
$BODY$
;