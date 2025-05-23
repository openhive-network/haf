-- When a HAF application is working on the blockchain head its context's irreversible
-- block is always behind a current block num. When for some reason an application
--  stuck for a while, then after re-run it will process block one by one instead of move
-- to massively processing all irreversible blocks that were added during pause.


CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __account hafd.accounts%ROWTYPE;
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );

    __account = ( 5, 'initminer', 1 );
    PERFORM hive.push_block(
         ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , ARRAY[ __account ]
        , NULL
        , NULL
    );

    PERFORM hive.app_next_block( 'context' ); -- (1,1)
    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
    PERFORM hive.set_irreversible( 1 );


    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
    PERFORM hive.set_irreversible( 2 );

    PERFORM hive.push_block(
         ( 4, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
    PERFORM hive.set_irreversible( 3 );

    PERFORM hive.push_block(
            ( 5, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        );
    -- now the context is 2 blocks behind the  head block
    -- and all irreversible blocks are processed

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
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks;
    RAISE NOTICE 'wrong result %', __blocks;
    ASSERT __blocks IS NOT NULL, 'Null returned';
    ASSERT __blocks.first_block = 2, 'Wrong first block';
    ASSERT __blocks.last_block = 3, 'Wrong first block';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks;
    ASSERT __blocks IS NOT NULL, 'Null returned 3';
    ASSERT __blocks.first_block = 3, 'Wrong first block 3';
    ASSERT __blocks.last_block = 3, 'Wrong last block 3';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks;
    ASSERT __blocks IS NOT NULL, 'Null returned 4';
    ASSERT __blocks.first_block = 4, 'Wrong first block 4';
    ASSERT __blocks.last_block = 4, 'Wrong last block 4';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks;
    ASSERT __blocks IS NULL, 'Null not returned for event IR(3)';
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks;
    ASSERT __blocks IS NOT NULL, 'Null returned 5';
    ASSERT __blocks.first_block = 5, 'Wrong first block 5';
    ASSERT __blocks.last_block = 5, 'Wrong last block 5';

END
$BODY$
;




