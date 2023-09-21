-- Testing consensus state provider with blocks being reversed due to a fork
DROP PROCEDURE IF EXISTS haf_admin_procedure_test_given;
CREATE PROCEDURE haf_admin_procedure_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
-- massive sync
INSERT INTO hive.blocks
VALUES
      ( 1, '\x0000000109833ce528d5bbfb3f6225b39ee10086', '\x0000000000000000000000000000000000000000', '2016-03-24 16:05:00', 3, '\x0000000000000000000000000000000000000000', NULL, '\x204f8ad56a8f5cf722a02b035a61b500aa59b9519b2c33c77a80c0a714680a5a5a7a340d909d19996613c5e4ae92146b9add8a7a663eef37d837ef881477313043', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 2000, 3000, 3000, 0, 0)
    , ( 2, '\x00000002ed04e3c3def0238f693931ee7eebbdf1', '\x0000000109833ce528d5bbfb3f6225b39ee10086', '2016-03-24 16:05:36', 3, '\x0000000000000000000000000000000000000000', NULL, '\x1f3e85ab301a600f391f11e859240f090a9404f8ebf0bf98df58eb17f455156e2d16e1dcfc621acb3a7acbedc86b6d2560fdd87ce5709e80fa333a2bbb92966df3', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 4000, 6000, 6000, 0, 0)
    , ( 3, '\x000000035b094a812646289c622dba0ba67d1ffe', '\x00000002ed04e3c3def0238f693931ee7eebbdf1', '2016-03-24 16:05:39', 3, '\x0000000000000000000000000000000000000000', NULL, '\x205ad1d3f0d42abcfdacb179de1acecf873be432cc546dde6b35184d261868b47b17dc1717b78a1572843fdd71a654e057db03f2df5d846b71606ec80455a199a6', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 6000, 9000, 9000, 0, 0)
    , ( 4, '\x00000004f9de0cfeb08c9d7d9d1fe536d902dc4a', '\x000000035b094a812646289c622dba0ba67d1ffe', '2016-03-24 16:05:42', 3, '\x0000000000000000000000000000000000000000', NULL, '\x202c7e5cada5104170365a83734a229eac0e427af5ed03fe2268e79bb9b05903d55cb96547987b57cd1ba5ed1a5ae1a9372f0ee6becfd871c2fcc26dc8b057149e', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 8000, 12000, 12000, 0, 0)
    , ( 5, '\x00000005014b5562a1133070d8bee536de615329', '\x00000004f9de0cfeb08c9d7d9d1fe536d902dc4a', '2016-03-24 16:05:45', 3, '\x0000000000000000000000000000000000000000', NULL, '\x1f508f1124db7f1442946b5e3b3a5f822812e54e18dffcda83385a9664b825d27214f0cdd0a0a7e7aeb6467f428fbc291c6f64b60da29e8ad182c20daf71b68b8b', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 10000, 15000, 15000, 0, 0)

;



    INSERT INTO  hive.accounts  (id, name, block_num) VALUES 
                                (0	,'miners',	1),
                                (1	,'null',	1),
                                (2	,'temp',	1),
                                (3	,'initminer',	1),
                                (5	,'initminer2',	1),
                                (48,	'steemit16',	1),
                                (224,	'emily',	1)
;
PERFORM hive.end_massive_sync(5);

-- live sync
PERFORM hive.push_block(
     ( 6, '\x00000006e323e35687e160b8aec86f1e56d4c902', '\x00000005014b5562a1133070d8bee536de615329', '2016-03-24 16:05:48', 3, '\x0000000000000000000000000000000000000000', NULL, '\x1f6bcfe700cc88f5c91fbc82fdd46623fed31c95071dbfedafa9faaad76ac788527658fb11ae57a602feac3d8a5b8d2ec4c47ef361b9f64d5b9db267642fc78bc3', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 12000, 18000, 18000, 0, 0)
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
     ( 7, '\x000000079ff02a2dea6c4d9a27f752233d4a66b4', '\x00000006e323e35687e160b8aec86f1e56d4c902', '2016-03-24 16:05:51', 3, '\x0000000000000000000000000000000000000000', NULL, '\x1f5202b4570f1b0d8b197a5f5729389e762ca7e6b74d179d54c51cf4f79694eb130c2cc39d31fa29e2d54dc9aa9fab83fedba981d415e0b341f0040183e2d1997c', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 14000, 21000, 21000, 0, 0)
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.set_irreversible( 6 );

PERFORM hive.push_block(
     ( 8, '\x000000084f957cc170a27c8330293a3343f82c23', '\x000000079ff02a2dea6c4d9a27f752233d4a66b4', '2016-03-24 16:05:54', 3, '\x0000000000000000000000000000000000000000', NULL, '\x2050e555bd40af001737ccebc03d4b6e104eaa9f46f1acac03f9d4dd1b7af3cf1c45c6e232364fda7f6c72ff2942d0a35d148ee4b6ba52332c11c3b528cd01d8c3', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 16000, 24000, 24000, 0, 0)
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
     ( 9, '\x00000009f35198cfd8a866868538bed3482d61a4', '\x000000084f957cc170a27c8330293a3343f82c23', '2016-03-24 16:05:57', 3, '\x0000000000000000000000000000000000000000', NULL, '\x2044cd87f6f0a98b37c520b61349de4b36ab82aa8cc799c7ce0f14635ae2a266b02412af616deecba6cda06bc1f3823b2abd252cfe592643920e67ccdc73aef6f9', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 18000, 27000, 27000, 0, 0)
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
    -- csp creates csp_session
    ASSERT  NOT EXISTS (SELECT 1 FROM hive.sessions WHERE name = 'context'), 'Sessions table should not contain ''context'' entry before hive.session_setup (via app_state_provider_import)';
    
    -- csp creates csp_session
    PERFORM hive.app_state_provider_import('CSP', 'context');

    -- csp check if sessions table is filled
    ASSERT EXISTS (SELECT 1 FROM hive.sessions WHERE name = 'context'), 'Sessions table should contain ''context'' entry after hive.session_setup (via app_state_provider_import)';


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
RAISE NOTICE 'blocks: %', __blocks;
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (6,6)';
ASSERT __blocks = (6,6), 'Incorrect range (6,6)';
INSERT INTO A.table1(id) VALUES( 6 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');


SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 7
RAISE NOTICE 'blocks: %', __blocks;
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (7,7)';
ASSERT __blocks = (7,7), 'Incorrect range (7,7)';
INSERT INTO A.table1(id) VALUES( 7 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');


SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- SET_IRREVERSIBLE_EVENT
RAISE NOTICE 'blocks: %', __blocks;
ASSERT __blocks IS NULL, 'NUll was not returned for processing SET_IRREVERSIBLE_EVENT';

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 8
RAISE NOTICE 'blocks: %', __blocks;
ASSERT ( SELECT COUNT(*) FROM A.table1 ) = 7, 'Wrong number of rows before after fork(7)';
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (8,8)';
ASSERT __blocks = (8,8), 'Incorrect range (8,8)';
ASSERT '\x000000084f957cc170a27c8330293a3343f82c23'::bytea = ( SELECT hash FROM hive.context_blocks_view WHERE num = 8 ), 'Unexpect hash of block 8 1st';
INSERT INTO A.table1(id) VALUES( 8 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');


SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 9
RAISE NOTICE 'blocks: %', __blocks;
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (9,9)';
ASSERT __blocks = (9,9), 'Incorrect range (9,9)';
ASSERT '\x00000009f35198cfd8a866868538bed3482d61a4'::bytea = ( SELECT hash FROM hive.context_blocks_view WHERE num = 9 ), 'Unexpect hash of block 9 1st';
INSERT INTO A.table1(id) VALUES( 9 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');



SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 9
RAISE NOTICE 'blocks: %', __blocks;


PERFORM hive.back_from_fork( 7 );
SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 9
RAISE NOTICE 'blocks: %', __blocks;

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 9
RAISE NOTICE 'blocks: %', __blocks;

PERFORM hive.push_block(
        -- ( 8, '\x000000084f957cc170a27c8330293a3343f82c23', '\x000000079ff02a2dea6c4d9a27f752233d4a66b4', '2016-03-24 16:05:54', 3, '\x0000000000000000000000000000000000000000', NULL, '\x2050e555bd40af001737ccebc03d4b6e104eaa9f46f1acac03f9d4dd1b7af3cf1c45c6e232364fda7f6c72ff2942d0a35d148ee4b6ba52332c11c3b528cd01d8c3', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 16000, 24000, 24000, 0, 0)
         ( 8,   '\x00000008e189194814783f9b4fee1d0036aa7098', '\x000000079ff02a2dea6c4d9a27f752233d4a66b4', '2016-03-24 16:05:55', 3, '\x0000000000000000000000000000000000000000', NULL, '\x2050e555bd40af001737ccebc03d4b6e104eaa9f46f1acac03f9d4dd1b7af3cf1c45c6e232364fda7f6c72ff2942d0a35d148ee4b6ba52332c11c3b528cd01d8c3', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 16000, 24000, 24000, 0, 0)
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
COMMIT;    
SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 8
RAISE NOTICE 'blocks: %', __blocks;

ASSERT ( SELECT COUNT(*) FROM A.table1 ) = 7, 'Wrong number of rows before after fork(7)';
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (8,8)';
ASSERT __blocks = (8,8), 'Incorrect range (8,8)';
ASSERT '\x00000008e189194814783f9b4fee1d0036aa7098'::bytea = ( SELECT hash FROM hive.context_blocks_view WHERE num = 8 ), 'Unexpect hash of block 8 1.5';
INSERT INTO A.table1(id) VALUES( 8 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');

PERFORM hive.push_block(
        ( 9, '\x00000009d361e47148af8fe7598c4f2db74237ed', '\x00000008e189194814783f9b4fee1d0036aa7098', '2016-03-24 16:05:57', 3, '\x0000000000000000000000000000000000000000', NULL, '\x2044cd87f6f0a98b37c520b61349de4b36ab82aa8cc799c7ce0f14635ae2a266b02412af616deecba6cda06bc1f3823b2abd252cfe592643920e67ccdc73aef6f9', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 18000, 27000, 27000, 0, 0)
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
COMMIT;    




SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 9
RAISE NOTICE 'blocks: %', __blocks;
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (9,9)';
ASSERT __blocks = (9,9), 'Incorrect range (9,9)';
ASSERT '\x00000009d361e47148af8fe7598c4f2db74237ed'::bytea = ( SELECT hash FROM hive.context_blocks_view WHERE num = 9 ), 'Unexpect hash of block 9 2nd';
INSERT INTO A.table1(id) VALUES( 9 );
    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');


PERFORM hive.push_block(
        (10, '\x0000000ac0b1f742de471556c998352c5b9866b3', '\x00000009d361e47148af8fe7598c4f2db74237ed', '2016-03-24 16:06:00', 3, '\x0000000000000000000000000000000000000000', NULL, '\x1f6ac53a8bb6ca885e988baafb1363b98e8807f62e6256462269b7288c568010096402d9bd2d8a69549568477f79570e8a41474daee2b7d29c623a0b5649081417', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 20000, 30000, 30000, 0, 0)
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );


SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 10
COMMIT;
RAISE NOTICE 'blocks: %', __blocks;
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks (10,10)';
ASSERT __blocks = (10,10), 'Incorrect range (10,10)';
ASSERT '\x0000000ac0b1f742de471556c998352c5b9866b3'::bytea = ( SELECT hash FROM hive.context_blocks_view WHERE num = 10 ), 'Unexpect hash of block 10 2nd';
INSERT INTO A.table1(id) VALUES( 10 );


    PERFORM hive.update_state_provider_csp(__blocks.first_block, __blocks.last_block, 'context');


-- SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks;
-- ASSERT __blocks IS NULL, 'NULL was not returned from BACK_FROM_FORK';

-- SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- no blocks
-- ASSERT __blocks IS NULL, 'Null is expected';

END;
$BODY$
;
