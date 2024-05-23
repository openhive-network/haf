-- When a HAF application is working on the blockchain head its context's irreversible
-- block is always behind a current block num. When for some reason an application
--  stuck for a while, then after re-run it will process block one by one instead of move
-- to massively processing all irreversible blocks that were added during pause.


CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __account hive.accounts%ROWTYPE;
    _context_stages hive.application_stages := ARRAY[ ('stage2',1 ,2 )::hive.application_stage, hive.live_stage() ];
    __blocks hive.blocks_range;
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    UPDATE hive.contexts hc SET stages = _context_stages;

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

    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); --(1,1)
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
    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks );
    ASSERT __blocks IS NOT NULL, 'Null returned';
    ASSERT hive.app_context_is_attached( 'context' ) = FALSE, 'Context is still attached';
    ASSERT __blocks.first_block = 2, 'Wrong first block 2';
    ASSERT __blocks.last_block = 3, 'Wrong last block 3';

    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks );
    ASSERT __blocks IS NOT NULL, 'Null returned 3';
    ASSERT hive.app_context_is_attached( 'context' ) = TRUE, 'Context is not attached (1)';
    ASSERT __blocks.first_block = 4, 'Wrong first block 4';
    ASSERT __blocks.last_block = 4, 'Wrong last block 4';

    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks );
    ASSERT hive.app_context_is_attached( 'context' ) = TRUE, 'Context is not attached (2)';
    ASSERT __blocks IS NULL, 'Null not returned for IR(3)';

    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks );
    ASSERT __blocks IS NOT NULL, 'Null returned 5';
    ASSERT hive.app_context_is_attached( 'context' ) = TRUE, 'Context is not attached (3)';
    ASSERT __blocks.first_block = 5, 'Wrong first block 5';
    ASSERT __blocks.last_block = 5, 'Wrong last block 5';
END
$BODY$
;




