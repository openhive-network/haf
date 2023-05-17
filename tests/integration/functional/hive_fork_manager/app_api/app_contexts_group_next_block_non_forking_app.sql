DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
      VALUES  ( 1, '\xBADD10', '\xCAFE40', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , ( 2, '\xBADD20', '\xCAFE40', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , ( 3, '\xBADD30', '\xCAFE40', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
    ;

    PERFORM hive.end_massive_sync(4);

    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_create_context( 'context_b' );
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
    __result hive.blocks_range;
BEGIN
    SELECT * INTO __result FROM hive.app_next_block( ARRAY[ 'context_b', 'context' ] );
    ASSERT __result = (1,4), 'Wrong blocks range instead of (1,4)';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name = 'context' ) = 4, 'Internally irreversible_block has changed';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name = 'context_b' ) = 4, 'Internally irreversible_block has changed -b';

    SELECT * INTO __result FROM hive.app_next_block( ARRAY[ 'context_b', 'context' ] );
    ASSERT __result = (2,4), 'Wrong blocks range instead of (2,4)';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name = 'context' ) = 4, 'Internally irreversible_block has changed';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name = 'context_b' ) = 4, 'Internally irreversible_block has changed b';

    SELECT * INTO __result FROM hive.app_next_block( ARRAY[ 'context_b', 'context' ] );
    ASSERT __result = (3,4), 'Wrong blocks range instead of (3,4)';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name = 'context' ) = 4, 'Internally irreversible_block has changed';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name = 'context_b' ) = 4, 'Internally irreversible_block has changed b';

    SELECT * INTO __result FROM hive.app_next_block( ARRAY[ 'context_b', 'context' ] );
    ASSERT __result = (4,4), 'Wrong blocks range instead of (4,4)';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name = 'context' ) = 4, 'Internally irreversible_block has changed';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name = 'context_b' ) = 4, 'Internally irreversible_block has changed';

    SELECT * INTO __result FROM hive.app_next_block( ARRAY[ 'context_b', 'context' ] );
    ASSERT __result IS NULL, 'NUll was expected after end on irreversible blocks';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name = 'context' ) = 4, 'Internally irreversible_block has changed';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name = 'context_b' ) = 4, 'Internally irreversible_block has changed b';
END
$BODY$
;




