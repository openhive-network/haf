
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __context_stages hive.application_stages := ARRAY[ ('stage1',2 ,5 )::hive.application_stage, hive.live_stage() ];
    __blocks hive.blocks_range;
BEGIN
    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync(1);

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a', _stages => __context_stages  );

    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );

    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.set_irreversible( 2 );

    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    -- simualates hived massive sync
    INSERT INTO hive.blocks
    VALUES   ( 3, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
           , ( 4, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
           , ( 5, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
           , ( 6, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;


    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); --block (1, 1), NEW_BLOCK(2) NOT PROCESSED 1
    INSERT INTO A.table1(id) VALUES ( 1 );
    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); --block (2,2), NEW_BLOCK(2) 1
    INSERT INTO A.table1(id) VALUES ( 2 );
    PERFORM hive.app_next_block( 'context' ); --NULL, NEW_IRREVERSIBLE 2
    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); --(3,3) NEW_BLOCK(3) 3
    INSERT INTO A.table1(id) VALUES ( 3 );

    PERFORM hive.end_massive_sync(3);
    PERFORM hive.end_massive_sync(5);
    PERFORM hive.end_massive_sync(6);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    -- NOTHING TODO HERE
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    ASSERT ( SELECT events_id FROM hive.contexts WHERE name='context' LIMIT 1 ) = 4, 'Wrong events id 4';
    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); -- MASSIVE_SYNC

    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks';
    RAISE NOTICE 'Blocks range = %', __blocks;
    ASSERT __blocks.first_block = 4, 'Incorrect first block';
    ASSERT __blocks.last_block = 6, 'Incorrect last range';
    ASSERT hive.app_context_is_attached( 'context' ) = FALSE, 'Context context is attached';

    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context' ) = 6, 'Wrong current block num 4';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name='context' ) = 6, 'Wrong irreversible';

    ASSERT ( SELECT COUNT(*)  FROM A.table1 ) = 3, 'Wrong number of rows in app table';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 1 ), 'No id 1';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 2 ), 'No id 2';

    ASSERT NOT EXISTS ( SELECT * FROM hive.shadow_a_table1 ), 'Shadow table is not empty';

    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks );
    ASSERT hive.app_context_is_attached( 'context' ) = TRUE, 'Context context is not attached';
    ASSERT __blocks IS NULL, 'Not NULL returned when all blocks are processed';
END
$BODY$
;




