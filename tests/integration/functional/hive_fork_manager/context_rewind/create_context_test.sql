DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'my_context' );
    PERFORM hive.context_create( 'my_context2' );
END
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
    ASSERT EXISTS ( SELECT FROM hive.contexts WHERE name = 'my_context' AND current_block_num = 0 AND irreversible_block = 0 AND is_attached = TRUE );
    ASSERT EXISTS ( SELECT FROM hive.contexts WHERE name = 'my_context2' AND current_block_num = 0 AND irreversible_block = 0 AND is_attached = TRUE );
END
$BODY$
;




