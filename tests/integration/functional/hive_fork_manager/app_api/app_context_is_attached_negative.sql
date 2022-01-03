DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context_attached' );
    PERFORM hive.app_create_context( 'context_detached' );
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
    --NOTHING TO DO HERE
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
    BEGIN
        PERFORM hive.app_context_detach( 'not_existed_context' );
        ASSERT FALSE, 'No expected exception for a non existed context';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;


