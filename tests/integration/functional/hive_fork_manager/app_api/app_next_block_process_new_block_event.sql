DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES
          ( 0, 'OP 0', FALSE )
        , ( 1, 'OP 1', FALSE )
        , ( 2, 'OP 2', FALSE )
        , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync( 1 );

    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.app_create_context( 'context' );
    -- create a table to test forking app
    CREATE TABLE table1( id INT) INHERITS( hive.context );
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
    __first_blocks hive.blocks_range;
    __second_blocks hive.blocks_range;
    __third_blocks hive.blocks_range;
BEGIN
    SELECT * FROM hive.app_next_block( 'context' ) INTO __first_blocks;
    ASSERT __first_blocks.first_block = 1 AND __first_blocks.last_block = 1, 'Wrong first block';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __second_blocks;
    RAISE NOTICE 'Second block=%', __second_blocks;
    ASSERT __second_blocks.first_block = 2 AND __second_blocks.last_block = 2, 'Wrong second block';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __third_blocks;
    ASSERT __third_blocks IS NULL, 'Wrong second block';
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
    ASSERT EXISTS ( SELECT FROM hive.events_queue WHERE id = 2 AND event = 'NEW_BLOCK' AND block_num = 2 ), 'No event added';
    ASSERT ( SELECT COUNT(*) FROM hive.events_queue ) = 4, 'Unexpected number of events';

    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context' ) = 2, 'Wrong current block num';
END
$BODY$
;




