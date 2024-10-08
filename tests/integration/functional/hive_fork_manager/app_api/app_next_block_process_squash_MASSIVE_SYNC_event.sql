
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive_data.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive_data.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync(1);

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
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
    INSERT INTO hive_data.blocks
    VALUES   ( 3, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
           , ( 4, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
           , ( 5, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
           , ( 6, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    PERFORM hive.app_next_block( 'context' ); --block (1, 1), NEW_BLOCK(2) NOT PROCESSED 1
    INSERT INTO A.table1(id) VALUES ( 1 );
    PERFORM hive.app_next_block( 'context' ); --block (2,2), NEW_BLOCK(2) 1
    INSERT INTO A.table1(id) VALUES ( 2 );
    PERFORM hive.app_next_block( 'context' ); --NULL, NEW_IRREVERSIBLE 2
    PERFORM hive.app_next_block( 'context' ); --(3,3) NEW_BLOCK(3) 3
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
    ASSERT ( SELECT events_id FROM hive_data.contexts WHERE name='context' LIMIT 1 ) = 4, 'Wrong events id 4';
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- MASSIVE_SYNC

    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks';
    RAISE NOTICE 'Blocks range = %', __blocks;
    ASSERT __blocks.first_block = 4, 'Incorrect first block';
    ASSERT __blocks.last_block = 6, 'Incorrect last range';
    ASSERT ( SELECT events_id FROM hive_data.contexts WHERE name='context' LIMIT 1 ) = 7, 'Wrong events id 7'; -- MASSIVE_SYNC_EVENTS squashed

    ASSERT ( SELECT current_block_num FROM hive_data.contexts WHERE name='context' ) = 4, 'Wrong current block num 4';
    ASSERT ( SELECT events_id FROM hive_data.contexts WHERE name='context' ) = 7, 'Wrong events id 7';
    ASSERT ( SELECT irreversible_block FROM hive_data.contexts WHERE name='context' ) = 6, 'Wrong irreversible';

    ASSERT ( SELECT COUNT(*)  FROM A.table1 ) = 3, 'Wrong number of rows in app table';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 1 ), 'No id 1';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 2 ), 'No id 2';

    ASSERT NOT EXISTS ( SELECT * FROM hive_data.shadow_a_table1 ), 'Shadow table is not empty';
END
$BODY$
;




