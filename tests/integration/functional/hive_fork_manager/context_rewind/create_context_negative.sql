DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
-- GOT PREPARED DATA SCHEMA
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    BEGIN
        PERFORM hive.context_create( '*my_context' );
        ASSERT FALSE, 'Cannot catch expected exception: *my_context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.context_create( 'my context' );
        ASSERT FALSE, 'Cannot catch expected exception: my context';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT * FROM hive.contexts ), 'Some context were created';
END
$BODY$
;




