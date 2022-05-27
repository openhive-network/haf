-- the test check a real scenario with hived and applciation role, the order of fucntion call is:
-- hived_test_given->alice_test_given->hived_test_when->alice_test_when->hived_test_then->alice_test_then

DROP FUNCTION IF EXISTS hived_test_given;
CREATE FUNCTION hived_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
-- massive sync
INSERT INTO hive.blocks
VALUES
      ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5 )
    , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5 )
    , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5 )
    , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5 )
    , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5 )
;
INSERT INTO hive.accounts( id, name, block_num )
VALUES (5, 'initminer', 1)
;
PERFORM hive.end_massive_sync(5);

-- live sync
PERFORM hive.push_block(
         ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:25-07'::timestamp, 5 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
         ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:25-07'::timestamp, 5 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.set_irreversible( 6 );

PERFORM hive.push_block(
         ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:25-07'::timestamp, 5 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
         ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:25-07'::timestamp, 5 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.back_from_fork( 7 );

PERFORM hive.push_block(
         ( 8, '\xBADD81', '\xCAFE81', '2016-06-22 19:10:25-07'::timestamp, 5 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
         ( 9, '\xBADD91', '\xCAFE91', '2016-06-22 19:10:25-07'::timestamp, 5 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
END;
$BODY$
;

DROP FUNCTION IF EXISTS hived_test_when;
CREATE FUNCTION hived_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.back_from_fork( 8 );
    PERFORM hive.push_block(
         ( 9, '\xBADD92', '\xCAFE92', '2016-06-22 19:10:25-07'::timestamp, 5 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
END;
$BODY$
;

DROP FUNCTION IF EXISTS hived_test_then;
CREATE FUNCTION hived_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.push_block(
             ( 10, '\xBADD1010', '\xCAFE1010', '2016-06-22 19:10:25-07'::timestamp, 5 )
            , NULL
            , NULL
            , NULL
            , NULL
            , NULL
        );

    PERFORM hive.set_irreversible( 8 );
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_given;
CREATE FUNCTION alice_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    RETURN;
    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 1
    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks';
    RAISE NOTICE 'blocks: %', __blocks;
    ASSERT __blocks = (1,6), 'Incorrect first block (1,6)';
    INSERT INTO A.table1(id) VALUES( 1 );


    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 2
    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (2,5)';
    RAISE NOTICE 'blocks: %', __blocks;
    ASSERT __blocks = (2,6), 'Incorrect range (2,6)';
    INSERT INTO A.table1(id) VALUES( 2 );

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 3
    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (3,5)';
    RAISE NOTICE 'blocks: %', __blocks;
    ASSERT __blocks = (3,6), 'Incorrect range (3,6)';
    INSERT INTO A.table1(id) VALUES( 3 );

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 4
    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (4,5)';
    RAISE NOTICE 'blocks: %', __blocks;
    ASSERT __blocks = (4,6), 'Incorrect range (4,6)';
    INSERT INTO A.table1(id) VALUES( 4 );

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 5
    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (5,5)';
    RAISE NOTICE 'blocks: %', __blocks;
    ASSERT __blocks = (5,6), 'Incorrect range (5,6)';
    INSERT INTO A.table1(id) VALUES( 5 );

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 6
    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (6,6)';
    ASSERT __blocks = (6,6), 'Incorrect range (6,6)';
    INSERT INTO A.table1(id) VALUES( 6 );

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 7
    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (7,7)';
    ASSERT __blocks = (7,7), 'Incorrect range (7,7)';
    INSERT INTO A.table1(id) VALUES( 7 );
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- SET_IRREVERSIBLE_EVENT
    ASSERT __blocks IS NULL, 'NUll was not returned for processing SET_IRREVERSIBLE_EVENT';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks;
    ASSERT __blocks IS NULL, 'NULL was not returned from BACK_FROM_FORK';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 8
    ASSERT ( SELECT COUNT(*) FROM A.table1 ) = 7, 'Wrong number of rows after fork(7)';
    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (8,8)';
    ASSERT __blocks = (8,8), 'Incorrect range (8,8)';
    ASSERT '\xBADD81'::bytea = ( SELECT hash FROM hive.context_blocks_view WHERE num = 8 ), 'Unexpect hash of block 8';
    INSERT INTO A.table1(id) VALUES( 8 );

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 9
    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (9,9)';
    ASSERT __blocks = (9,9), 'Incorrect range (9,9)';
    ASSERT '\xBADD91'::bytea = ( SELECT hash FROM hive.context_blocks_view WHERE num = 9 ), 'Unexpect hash of block 9';
    INSERT INTO A.table1(id) VALUES( 9 );

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- no blocks
    ASSERT __blocks IS NULL, 'Null is expected';
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_when;
CREATE FUNCTION alice_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    RETURN;
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- BACK_FROM_FORK(8)
    ASSERT __blocks IS NULL, 'Null is expected';
    ASSERT ( SELECT COUNT(*) FROM A.table1 ) = 8, 'Wrong number of rows after fork(8)';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- block 9
    ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (9,9)';
    ASSERT __blocks = (9,9), 'Incorrect range (9,9)';
    ASSERT '\xBADD92'::bytea = ( SELECT hash FROM hive.context_blocks_view WHERE num = 9 ), 'Unexpect hash of block 9';
    INSERT INTO A.table1(id) VALUES( 9 );

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- no block 10
    ASSERT __blocks IS NULL, 'Null is not returned instead for block 10';
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_then;
CREATE FUNCTION alice_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    RETURN;
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- block 10
    ASSERT __blocks IS NOT NULL, 'Null is returned instead for block 10';
    ASSERT __blocks = (10,10), 'Incorrect range (10,10)';
END;
$BODY$
;

-- bob's account does not take any action in this test
DROP FUNCTION IF EXISTS bob_test_given;
CREATE FUNCTION bob_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- PREPARE STATE AS BOB
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_when;
CREATE FUNCTION bob_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- EXECUTE ACTION UDER TEST AS BOB
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_then;
CREATE FUNCTION bob_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- CHECK EXPECTED STATE AS BOB
END;
$BODY$
;

