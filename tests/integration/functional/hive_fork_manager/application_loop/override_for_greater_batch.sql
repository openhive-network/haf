
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __context_stages hafd.application_stages := ARRAY[ hive.stage('stage1',3 ,3 ), hafd.live_stage() ];
    __context_b_stages hafd.application_stages := ARRAY[ hive.stage('stage1',3 ,3 ), hafd.live_stage() ];
BEGIN
    INSERT INTO hafd.blocks
      VALUES  ( 1, '\xBADD10', '\xCAFE40', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , ( 2, '\xBADD20', '\xCAFE40', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , ( 3, '\xBADD30', '\xCAFE40', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
    ;

    PERFORM hive.end_massive_sync(5);

    CREATE SCHEMA A;

    PERFORM hive.app_create_context( 'context', _schema => 'a', _is_forking => FALSE, _stages => __context_stages );
    PERFORM hive.app_create_context( 'context_b', _schema => 'a', _is_forking => FALSE, _stages => __context_b_stages );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_error()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __result hive.blocks_range;
BEGIN
    CALL hive.app_next_iteration( ARRAY[ 'context_b', 'context' ], __result, 0 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __result hive.blocks_range;
BEGIN
    CALL hive.app_next_iteration( ARRAY[ 'context_b', 'context' ], __result, 4 );
    ASSERT __result = (1,4), 'Wrong blocks range instead of (1,4)';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context' ) = 5, 'Internally irreversible_block has changed';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context_b' ) = 5, 'Internally irreversible_block has changed -b';
    ASSERT hive.app_context_is_attached( 'context' ) = FALSE, 'Context context is attached (1)';
    ASSERT hive.app_context_is_attached( 'context_b' ) = FALSE, 'Context_b context is attached (1)';

    CALL hive.app_next_iteration( ARRAY[ 'context_b', 'context' ], __result, 5 );
    ASSERT __result = (5,5), 'Wrong blocks range instead of (5,5)';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context' ) = 5, 'Internally irreversible_block has changed';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context_b' ) = 5, 'Internally irreversible_block has changed b';

    CALL hive.app_next_iteration( ARRAY[ 'context_b', 'context' ], __result );
    ASSERT __result IS NULL, 'Not NULL returned when there are no blocks to process';
END
$BODY$
;




