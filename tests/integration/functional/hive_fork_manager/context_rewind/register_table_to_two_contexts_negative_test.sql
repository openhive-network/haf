
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    PERFORM hive.context_create( 'context2' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        CREATE TABLE table1( id SERIAL PRIMARY KEY, smth INTEGER, name TEXT ) INHERITS( hive.context, hive.context2 );
        ASSERT FALSE, 'Did not throw exception';
    EXCEPTION WHEN OTHERS THEN
        RETURN;
    END;
END;
$BODY$
;




