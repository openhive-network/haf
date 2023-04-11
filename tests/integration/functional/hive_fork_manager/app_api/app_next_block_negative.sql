DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'detached_context' );
    PERFORM hive.app_context_detach( 'detached_context' );
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
DECLARE
BEGIN
    BEGIN
        PERFORM hive.app_next_block( 'context' );
        ASSERT FALSE, 'No expected exception for unexisted context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_block( 'detached_context' );
        ASSERT FALSE, 'No expected exception for a detached context';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    -- NOTHING TO CHECK HERE
END
$BODY$
;




