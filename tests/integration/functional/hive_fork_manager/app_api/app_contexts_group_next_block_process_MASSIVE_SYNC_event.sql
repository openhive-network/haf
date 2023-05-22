DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync(1);

    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );

    PERFORM hive.app_create_context( 'context_b' );
    CREATE SCHEMA B;
    CREATE TABLE B.table1(id  INTEGER ) INHERITS( hive.context_b );

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

    PERFORM hive.app_next_block( ARRAY[ 'context', 'context_b' ] ); --block 1 (squash massive sync)
    INSERT INTO A.table1(id) VALUES ( 1 );
    INSERT INTO B.table1(id) VALUES ( 1 );
    PERFORM hive.app_next_block( ARRAY[ 'context', 'context_b' ]  ); --block 2 - irreversible
    INSERT INTO A.table1(id) VALUES ( 2 );
    INSERT INTO B.table1(id) VALUES ( 2 );
    PERFORM hive.app_next_block( ARRAY[ 'context', 'context_b' ] ); --set irreversible block 2
    PERFORM hive.app_next_block( ARRAY[ 'context', 'context_b' ] ); --block 3 --reversible
    INSERT INTO A.table1(id) VALUES ( 3 ); --reversible
    INSERT INTO B.table1(id) VALUES ( 3 ); --reversible

    PERFORM hive.end_massive_sync(6);
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
    __blocks hive.blocks_range;
BEGIN
    SELECT * FROM hive.app_next_block( ARRAY[ 'context', 'context_b' ] ) INTO __blocks; -- MASSIVE_SYNC
    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks';
    RAISE NOTICE 'Blocks range = %', __blocks;
    ASSERT __blocks.first_block = 3, 'Incorrect first block';
    ASSERT __blocks.last_block = 6, 'Incorrect last range';
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
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context' ) = 3, 'Wrong current block num';
    ASSERT ( SELECT events_id FROM hive.contexts WHERE name='context' ) = 5, 'Wrong events id';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name='context' ) = 6, 'Wrong irreversible';

    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context_b' ) = 3, 'Wrong current block num b';
    ASSERT ( SELECT events_id FROM hive.contexts WHERE name='context_b' ) = 5, 'Wrong events id b';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name='context_b' ) = 6, 'Wrong irreversible b';

    ASSERT ( SELECT COUNT(*)  FROM A.table1 ) = 2, 'Wrong number of rows in app table';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 1 ), 'No id 1';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 2 ), 'No id 2';

    ASSERT ( SELECT COUNT(*)  FROM B.table1 ) = 2, 'Wrong number of rows in app table b';
    ASSERT EXISTS ( SELECT *  FROM B.table1 WHERE id = 1 ), 'No id 1 b';
    ASSERT EXISTS ( SELECT *  FROM B.table1 WHERE id = 2 ), 'No id 2 b';

    ASSERT NOT EXISTS ( SELECT * FROM hive.shadow_a_table1 ), 'Shadow table is not empty';
    ASSERT NOT EXISTS ( SELECT * FROM hive.shadow_b_table1 ), 'Shadow table is not empty b';
END
$BODY$
;




