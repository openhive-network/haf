DROP FUNCTION IF EXISTS test_hived_test_given;
CREATE FUNCTION test_hived_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    ALTER ROLE alice SET local_preload_libraries TO 'libquery_supervisor.so';
    ALTER ROLE bob RESET local_preload_libraries;
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
    --ALTER ROLE alice RESET local_preload_libraries;
    PERFORM pg_sleep( 2 );
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
    ALTER ROLE bob SET local_preload_libraries TO 'libquery_supervisor.so';
    PERFORM pg_sleep( 2 );
END;
$BODY$
;

