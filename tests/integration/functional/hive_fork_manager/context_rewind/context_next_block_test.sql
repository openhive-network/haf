
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'my_context', 'a' );
    PERFORM hive.context_create( 'my_context2', 'a' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
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

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM hafd.contexts WHERE name = 'my_context' AND current_block_num = 1 );
    ASSERT EXISTS ( SELECT FROM hafd.contexts WHERE name = 'my_context2' AND current_block_num = 2 );
END
$BODY$
;




