
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __context_stages hafd.application_stages := ARRAY[ hive.stage('stage1',3 ,5 ), hafd.live_stage() ];
    __blocks hive.blocks_range;
BEGIN
    INSERT INTO hafd.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync(1);

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a', _stages => __context_stages  );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );

    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); -- 1,
    INSERT INTO A.table1(id) VALUES ( 1 );
    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); -- attach the context

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
    INSERT INTO hafd.blocks
    VALUES   ( 3, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
           , ( 4, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
           , ( 5, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
           , ( 6, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); --block 2 - irreversible

    INSERT INTO A.table1(id) VALUES ( 2 );
    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); --set irreversible block 2
    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); --block 3 --reversible
    INSERT INTO A.table1(id) VALUES ( 3 ); --reversible

    PERFORM hive.back_from_fork( 2 );

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
    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); -- MASSIVE_SYNC
    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks );
    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks';
    RAISE NOTICE 'Blocks range = %', __blocks;
    ASSERT __blocks.first_block = 3, 'Incorrect first block';
    ASSERT __blocks.last_block = 6, 'Incorrect last range';
    ASSERT hive.app_context_is_attached( 'context' ) = FALSE, 'Context context is attached';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name='context' ) = 6, 'Wrong current block num';
    -- ASSERT ( SELECT events_id FROM hafd.contexts WHERE name='context' ) = 6, 'Wrong events id';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name='context' ) = 6, 'Wrong irreversible';

    ASSERT ( SELECT COUNT(*)  FROM A.table1 ) = 2, 'Wrong number of rows in app table';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 1 ), 'No id 1';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 2 ), 'No id 2';


    ASSERT NOT EXISTS ( SELECT * FROM hafd.shadow_a_table1 ), 'Shadow table is not empty';
END
$BODY$
;




