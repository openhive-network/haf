DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
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
DECLARE
    __context_exists BOOL;
BEGIN
    SELECT hive.app_context_exists( 'context' ) INTO __context_exists;
    ASSERT __context_exists = TRUE, 'Context marked as not existed';

    SELECT hive.app_context_exists( 'context2' ) INTO __context_exists;
    ASSERT __context_exists = FALSE, 'Context marked as existed';
END
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

END
$BODY$
;




