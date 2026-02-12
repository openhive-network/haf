\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __context_stages hafd.application_stages := ARRAY[ hive.stage('stage1',3 ,3 ), hafd.live_stage() ];
    __context_b_stages hafd.application_stages := ARRAY[ hive.stage('stage1',3 ,3 ), hafd.live_stage() ];
BEGIN
    PERFORM test.create_blocks(1, 5);

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
         , (6, 'alice', hafd.make_block_id(1, 0))
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
    CALL hive.app_next_iteration( ARRAY[ 'context_b', 'context' ], __result, -10 );
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
    CALL hive.app_next_iteration( ARRAY[ 'context_b', 'context' ], __result, 1 );
    ASSERT __result = (1,1), 'Wrong blocks range instead of (1,1)';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context' ) = 5, 'Internally irreversible_block has changed';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context_b' ) = 5, 'Internally irreversible_block has changed -b';
    ASSERT hive.app_context_is_attached( 'context' ) = FALSE, 'Context context is attached (1)';
    ASSERT hive.app_context_is_attached( 'context_b' ) = FALSE, 'Context_b context is attached (1)';

    CALL hive.app_next_iteration( ARRAY[ 'context_b', 'context' ], __result, 1 );
    ASSERT __result = (2,2), 'Wrong blocks range instead of (2,2)';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context' ) = 5, 'Internally irreversible_block has changed';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context_b' ) = 5, 'Internally irreversible_block has changed -b';
    ASSERT hive.app_context_is_attached( 'context' ) = FALSE, 'Context context is attached (1)';
    ASSERT hive.app_context_is_attached( 'context_b' ) = FALSE, 'Context_b context is attached (1)';

    CALL hive.app_next_iteration( ARRAY[ 'context_b', 'context' ], __result, 2 );
    ASSERT __result = (3,4), 'Wrong blocks range instead of (3,4)';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context' ) = 5, 'Internally irreversible_block has changed';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context_b' ) = 5, 'Internally irreversible_block has changed -b';
    ASSERT hive.app_context_is_attached( 'context' ) = FALSE, 'Context context is attached (1)';
    ASSERT hive.app_context_is_attached( 'context_b' ) = FALSE, 'Context_b context is attached (1)';

    CALL hive.app_next_iteration( ARRAY[ 'context_b', 'context' ], __result, 2 );
    ASSERT __result = (5,5), 'Wrong blocks range instead of (5,5)';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context' ) = 5, 'Internally irreversible_block has changed';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context_b' ) = 5, 'Internally irreversible_block has changed b';

    CALL hive.app_next_iteration( ARRAY[ 'context_b', 'context' ], __result, 2 );
    ASSERT __result IS NULL, 'Not NULL returned when there are no blocks to process';
END
$BODY$
;




