CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'alice_context' );
END;
$BODY$
;


CREATE OR REPLACE PROCEDURE alice_test_then()
        LANGUAGE 'plpgsql'
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