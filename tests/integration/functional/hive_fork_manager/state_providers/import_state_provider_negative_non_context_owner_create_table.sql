CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    BEGIN
        CREATE TABLE table1( id SERIAL PRIMARY KEY, smth INTEGER, name TEXT ) INHERITS( hive.context );
        ASSERT FALSE, 'No exception when haf_admin register a table into Alice''s context';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;





