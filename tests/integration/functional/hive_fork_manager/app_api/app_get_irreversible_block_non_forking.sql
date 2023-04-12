DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );

    -- hived inserts once irreversible block
    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
    ;
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
__result INT;
BEGIN
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 1, 'hive.app_get_irreversible_block !=1 (1)';

    PERFORM hive.app_next_block( 'context' ); -- no events
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 1, 'hive.app_get_irreversible_block !=1 (2)';

    --hived ends massive sync - irreversible = 1
    PERFORM hive.end_massive_sync( 1 );
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 1, 'hive.app_get_irreversible_block !=1 (3)';

    PERFORM hive.app_next_block( 'context' ); -- massive sync event
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 1, 'hive.app_get_irreversible_block !=1 (4)';

    PERFORM hive.push_block(
        ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 1, 'hive.app_get_irreversible_block !=1 (4)';

    PERFORM hive.push_block(
        ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 1, 'hive.app_get_irreversible_block !=1 (5)';

    PERFORM hive.set_irreversible( 2 );
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 2, 'hive.app_get_irreversible_block !=1 (6)';

    PERFORM hive.app_next_block( 'context' ); -- block 2
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 2, 'hive.app_get_irreversible_block !=2 (2)';

    PERFORM hive.app_next_block( 'context' ); -- block 3
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 2, 'hive.app_get_irreversible_block !=2 (3)';

    PERFORM hive.app_next_block( 'context' ); -- SET IRREVERSIBLE 2
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 2, 'hive.app_get_irreversible_block !=2 (4)';

    PERFORM hive.app_next_block( 'context' ); -- NO EVENT
    ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 2, 'hive.app_get_irreversible_block !=2 (5)';
END
$BODY$
;





