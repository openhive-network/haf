DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'my_context' );
    PERFORM hive.context_create( 'my_context2' );
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
    __block1 INTEGER := -1;
    __block2 INTEGER := -1;
BEGIN
    SELECT  hive.context_next_block( 'my_context' ) INTO __block1;
    PERFORM hive.context_next_block( 'my_context2' );
    SELECT hive.context_next_block( 'my_context2' ) INTO __block2;

    ASSERT __block1 = 1;
    ASSERT __block2 = 2;
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
    ASSERT EXISTS ( SELECT FROM hive.contexts WHERE name = 'my_context' AND current_block_num = 1 );
    ASSERT EXISTS ( SELECT FROM hive.contexts WHERE name = 'my_context2' AND current_block_num = 2 );
END
$BODY$
;




