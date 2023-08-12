DROP PROCEDURE IF EXISTS haf_admin_procedure_test_given;
CREATE PROCEDURE haf_admin_procedure_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
-- massive sync
INSERT INTO hive.blocks
VALUES
      ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
;
INSERT INTO hive.accounts( id, name, block_num )
VALUES (5, 'initminer', 1)
;
PERFORM hive.end_massive_sync(5);

-- live sync
PERFORM hive.push_block(
         ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
         ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.set_irreversible( 6 );

PERFORM hive.push_block(
         ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
         ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
END;
$BODY$
;

DROP PROCEDURE IF EXISTS haf_admin_procedure_test_when;
CREATE PROCEDURE haf_admin_procedure_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
__blocks hive.blocks_range;
BEGIN
PERFORM hive.app_create_context( 'context' );
CREATE SCHEMA A;
CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );
    RAISE NOTICE 'mtlk in haf_admin_procedure_test_when 01';
    -- csp creates csp_session
    ASSERT  NOT EXISTS (SELECT 1 FROM hive.sessions WHERE name = 'context'), 'Sessions table should not contain ''context'' entry before hive.create_session (via app_state_provider_import)';
    
    RAISE NOTICE 'mtlk in haf_admin_procedure_test_when 02 toolbox.get_consensus_storage_path=%', toolbox.get_consensus_storage_path();

    -- csp creates csp_session
    PERFORM hive.app_state_provider_import( 'CSP', 'context' , toolbox.get_consensus_storage_path());

    RAISE NOTICE 'mtlk in haf_admin_procedure_test_when 03';

    -- csp check if sessions table is filled
    ASSERT EXISTS (SELECT 1 FROM hive.sessions WHERE name = 'context'), 'Sessions table should contain ''context'' entry after hive.create_session (via app_state_provider_import)';

    RAISE NOTICE 'mtlk in haf_admin_procedure_test_when 04';


SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 1 MASSIVE SYNC EVENT
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks';
RAISE NOTICE 'Blocks: %', __blocks;
ASSERT __blocks = (1,6), 'Incorrect first block (1,6)';
INSERT INTO A.table1(id) VALUES( 1 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');



SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 2
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (2,5)';
RAISE NOTICE 'blocks: %', __blocks;
ASSERT __blocks = (2,6), 'Incorrect range (2,6)';
INSERT INTO A.table1(id) VALUES( 2 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 3
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (3,5)';
RAISE NOTICE 'blocks: %', __blocks;
ASSERT __blocks = (3,6), 'Incorrect range (3,6)';
INSERT INTO A.table1(id) VALUES( 3 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 4
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (4,5)';
RAISE NOTICE 'blocks: %', __blocks;
ASSERT __blocks = (4,6), 'Incorrect range (4,6)';
INSERT INTO A.table1(id) VALUES( 4 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 5
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (5,5)';
RAISE NOTICE 'blocks: %', __blocks;
ASSERT __blocks = (5,6), 'Incorrect range (5,6)';
INSERT INTO A.table1(id) VALUES( 5 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 6
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (6,6)';
ASSERT __blocks = (6,6), 'Incorrect range (6,6)';
INSERT INTO A.table1(id) VALUES( 6 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 7
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (7,7)';
ASSERT __blocks = (7,7), 'Incorrect range (7,7)';
INSERT INTO A.table1(id) VALUES( 7 );
SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- SET_IRREVERSIBLE_EVENT
ASSERT __blocks IS NULL, 'NUll was not returned for processing SET_IRREVERSIBLE_EVENT';
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 8
ASSERT ( SELECT COUNT(*) FROM A.table1 ) = 7, 'Wrong number of rows before after fork(7)';
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (8,8)';
ASSERT __blocks = (8,8), 'Incorrect range (8,8)';
ASSERT '\xBADD80'::bytea = ( SELECT hash FROM hive.context_blocks_view WHERE num = 8 ), 'Unexpect hash of block 8';
INSERT INTO A.table1(id) VALUES( 8 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');


SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 9
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (9,9)';
ASSERT __blocks = (9,9), 'Incorrect range (9,9)';
ASSERT '\xBADD90'::bytea = ( SELECT hash FROM hive.context_blocks_view WHERE num = 9 ), 'Unexpect hash of block 9';
INSERT INTO A.table1(id) VALUES( 9 );



--SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 9


PERFORM hive.back_from_fork( 7 );

--SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 9

PERFORM hive.push_block(
         ( 8, '\xBADD81', '\xCAFE81', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
         ( 9, '\xBADD91', '\xCAFE91', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks;
ASSERT __blocks IS NULL, 'NULL was not returned from BACK_FROM_FORK';

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 8
ASSERT ( SELECT COUNT(*) FROM A.table1 ) = 7, 'Wrong number of rows after fork(7)';
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (8,8)';
ASSERT __blocks = (8,8), 'Incorrect range (8,8)';
ASSERT '\xBADD81'::bytea = ( SELECT hash FROM hive.context_blocks_view WHERE num = 8 ), 'Unexpect hash of block 8';
INSERT INTO A.table1(id) VALUES( 8 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');


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




