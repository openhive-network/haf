DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
    ;

    PERFORM hive.end_massive_sync(1);

    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );

    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.set_irreversible( 2 );

    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    -- simualates hived massive sync
    INSERT INTO hive.blocks
    VALUES   ( 3, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
           , ( 4, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
           , ( 5, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
           , ( 6, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
    ;

    PERFORM hive.app_next_block( 'context' ); --block 1 (squash massive sync)
    INSERT INTO A.table1(id) VALUES ( 1 );
    PERFORM hive.app_next_block( 'context' ); --block 2 - irreversible
    INSERT INTO A.table1(id) VALUES ( 2 );
    PERFORM hive.app_next_block( 'context' ); --set irreversible block 2
    PERFORM hive.app_next_block( 'context' ); --block 3 --reversible
    INSERT INTO A.table1(id) VALUES ( 3 ); --reversible

    PERFORM hive.end_massive_sync(6);
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
    __blocks hive.blocks_range;
BEGIN
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- MASSIVE_SYNC
    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks';
    RAISE NOTICE 'Blocks range = %', __blocks;
    ASSERT __blocks.first_block = 3, 'Incorrect first block';
    ASSERT __blocks.last_block = 6, 'Incorrect last range';
END;
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
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context' ) = 3, 'Wrong current block num';
    ASSERT ( SELECT events_id FROM hive.contexts WHERE name='context' ) = 5, 'Wrong events id';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name='context' ) = 6, 'Wrong irreversible';

    ASSERT ( SELECT COUNT(*)  FROM A.table1 ) = 2, 'Wrong number of rows in app table';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 1 ), 'No id 1';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 2 ), 'No id 2';

    ASSERT NOT EXISTS ( SELECT * FROM hive.shadow_a_table1 ), 'Shadow table is not empty';
END
$BODY$
;




