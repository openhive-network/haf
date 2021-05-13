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
    PERFORM hive.context_create( 'my_context' );
    PERFORM hive.context_create( 'my_context2' );
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
    ASSERT EXISTS ( SELECT FROM hive.context WHERE name = 'my_context' AND current_block_num = -1 AND irreversible_block = -1 AND is_attached = TRUE );
    ASSERT EXISTS ( SELECT FROM hive.context WHERE name = 'my_context2' AND current_block_num = -1 AND irreversible_block = -1 AND is_attached = TRUE );
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
