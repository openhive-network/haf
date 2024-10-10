
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive_data.operation_types
    VALUES
          ( 0, 'OP 0', FALSE )
        , ( 1, 'OP 1', FALSE )
        , ( 2, 'OP 2', FALSE )
        , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive_data.blocks
    VALUES ( 2, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive_data.accounts( id, name, block_num )
    VALUES (5, 'initminer', NULL)
    ;

    PERFORM hive.end_massive_sync( 2 );

    PERFORM hive.push_block(
         ( 3, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    -- create a table to test forking app
    CREATE TABLE table1( id INT) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __first_blocks hive.blocks_range;
    __second_blocks hive.blocks_range;
    __third_blocks hive.blocks_range;
BEGIN
    SELECT * FROM hive.app_next_block( 'context' ) INTO __first_blocks;
    ASSERT __first_blocks.first_block = 2 AND __first_blocks.last_block = 2, 'Wrong first block';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __second_blocks;
    RAISE NOTICE 'Second block=%', __second_blocks;
    ASSERT __second_blocks.first_block = 3 AND __second_blocks.last_block = 3, 'Wrong second block';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __third_blocks;
    ASSERT __third_blocks IS NULL, 'Not returned NULL';
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM hive_data.events_queue WHERE id = 2 AND event = 'NEW_BLOCK' AND block_num = 3 ), 'No event added';
    ASSERT ( SELECT COUNT(*) FROM hive_data.events_queue ) = 4, 'Unexpected number of events';

    ASSERT ( SELECT current_block_num FROM hive_data.contexts WHERE name='context' ) = 3, 'Wrong current block num';
END
$BODY$
;




