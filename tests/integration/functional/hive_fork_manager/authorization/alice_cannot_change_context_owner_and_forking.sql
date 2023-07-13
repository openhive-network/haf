DROP FUNCTION IF EXISTS alice_test_given;
CREATE FUNCTION alice_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'alice_context' );
END;
$BODY$
;


DROP FUNCTION IF EXISTS alice_test_then;
CREATE FUNCTION alice_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    BEGIN
        UPDATE hive.contexts SET owner = 'BLABLA';
        ASSERT FALSE, 'Alice can update the context''s owner';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;