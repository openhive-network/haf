DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
-- massive sync
INSERT INTO hive.blocks
VALUES
      ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
    , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp )
    , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp )
    , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp )
    , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp )
;
PERFORM hive.end_massive_sync();

-- live sync
PERFORM hive.push_block(
         ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
         ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.set_irreversible( 6 );

PERFORM hive.push_block(
         ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
         ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.back_from_fork( 7 );

PERFORM hive.push_block(
         ( 8, '\xBADD81', '\xCAFE81', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
         ( 9, '\xBADD91', '\xCAFE91', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );
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
PERFORM hive.app_create_context( 'context' );
CREATE SCHEMA A;
CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.base );

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 1
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks';
ASSERT __blocks = (1,5), 'Incorrect first block (1,5)';
INSERT INTO A.table1(id) VALUES( 1 );


SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 2
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (2,5)';
ASSERT __blocks = (2,5), 'Incorrect range (2,5)';
INSERT INTO A.table1(id) VALUES( 2 );

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 3
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (3,5)';
ASSERT __blocks = (3,5), 'Incorrect range (3,5)';
INSERT INTO A.table1(id) VALUES( 3 );

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 4
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (4,5)';
ASSERT __blocks = (4,5), 'Incorrect range (4,5)';
INSERT INTO A.table1(id) VALUES( 4 );

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 5
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (5,5)';
ASSERT __blocks = (5,5), 'Incorrect range (5,5)';
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

-- here squash of forks should work
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

PERFORM hive.back_from_fork( 8 );
PERFORM hive.push_block(
         ( 9, '\xBADD92', '\xCAFE92', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- BACK_FROM_FORK(8)
ASSERT __blocks IS NULL, 'Null is expected';
ASSERT ( SELECT COUNT(*) FROM A.table1 ) = 8, 'Wrong number of rows after fork(8)';

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- block 9
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (9,9)';
ASSERT __blocks = (9,9), 'Incorrect range (9,9)';
ASSERT '\xBADD92'::bytea = ( SELECT hash FROM hive.context_blocks_view WHERE num = 9 ), 'Unexpect hash of block 9';
INSERT INTO A.table1(id) VALUES( 9 );

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
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
