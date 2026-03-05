
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
    ;

    -- end_massive_sync sets consistent_block=1
    PERFORM hive.end_massive_sync( 1 );

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'context', _schema => 'a' );
    PERFORM hive.app_create_context( 'context_b', _schema => 'a' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
__result INT;
BEGIN
    -- app_get_irreversible_block returns MAX(hafd.blocks.num) in irreversible-only mode
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 1, 'hive.app_get_irreversible_block !=1 (1)';
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context_b' ) ) = 1, 'hive.app_get_irreversible_block !=1 (1b)';

    PERFORM hive.app_next_block( ARRAY[ 'context', 'context_b' ] ); -- processes block 1
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 1, 'hive.app_get_irreversible_block !=1 (2)';
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context_b' ) ) = 1, 'hive.app_get_irreversible_block !=1 (2b)';

    -- push_block_lite inserts block and sets consistent_block
    PERFORM hive.push_block_lite(
        ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 2, 'hive.app_get_irreversible_block !=2 (3)';

    PERFORM hive.push_block_lite(
        ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 3, 'hive.app_get_irreversible_block !=3 (4)';
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context_b' ) ) = 3, 'hive.app_get_irreversible_block !=3 (4b)';

    PERFORM hive.app_next_block( ARRAY[ 'context', 'context_b' ] ); -- block 2
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 3, 'hive.app_get_irreversible_block !=3 (5)';
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context_b' ) ) = 3, 'hive.app_get_irreversible_block !=3 (5b)';

    PERFORM hive.app_next_block( ARRAY[ 'context', 'context_b' ] ); -- block 3
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 3, 'hive.app_get_irreversible_block !=3 (6)';
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context_b' ) ) = 3, 'hive.app_get_irreversible_block !=3 (6b)';
END
$BODY$
;

