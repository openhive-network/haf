DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    PERFORM hive.context_create( 'context2' );
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
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




