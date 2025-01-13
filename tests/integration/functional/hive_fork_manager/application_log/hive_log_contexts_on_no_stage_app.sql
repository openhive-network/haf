CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- here we pretend that 50 is the head block
    INSERT INTO hafd.blocks
    VALUES
           ( 1, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 50, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (1, 'initminer', 1)
    ;
    PERFORM hive.set_irreversible( 50 );
END;
$BODY$;


CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __alice_stages hafd.application_stages :=
        ARRAY[ hive.stage('stage2',100 ,100 )
            , hive.stage('stage1',10 ,10 )
            , hafd.live_stage()
            ];
    __alice1_stages hafd.application_stages :=
        ARRAY[ hive.stage('a1stage2',100 ,100 )
            , hive.stage('a1stage1',60 ,10 )
            , hafd.live_stage()
            ];
    __alice2_stages hafd.application_stages :=
        ARRAY[ hive.stage('a2stage2',45 ,100 )
            , hive.stage('a2stage1',40 ,10 )
            , hafd.live_stage()
            ];
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( 'alice', 'alice', _stages => __alice_stages );
    PERFORM hive.app_create_context( 'alice1', 'alice', _stages => __alice1_stages );
    PERFORM hive.app_create_context( 'alice2', 'alice', _stages => __alice2_stages );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    TRUNCATE hafd.contexts_log;
    ALTER SEQUENCE hafd.contexts_log_id_seq RESTART WITH 1;
END;
$BODY$;


CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __range_placeholder hive.blocks_range;
BEGIN
    CALL hive.app_next_iteration( ARRAY[ 'alice', 'alice1', 'alice2' ], __range_placeholder );

    -- force alice2 to reanalyze its stage
    UPDATE hafd.contexts hc
    SET loop.last_analyze_distance_to_head_block = 5
    WHERE hc.name = 'alice2';

    CALL hive.app_next_iteration( ARRAY[ 'alice2' ], __range_placeholder );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __current_stage hafd.application_stage;
BEGIN
    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
                context_name = 'alice'
            AND application_stage = 'stage1'
            AND event_type = 'STATE_CHANGED'
            AND application_block = 1
            AND application_fork = 1
            AND head_block  = 50
            AND head_fork_id = 1
    ), 'No alice STATE_CHANGED entry';

    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
                context_name = 'alice1'
            AND application_stage = 'live'
            AND event_type = 'STATE_CHANGED'
            AND application_block = 1
            AND application_fork = 1
            AND head_block  = 50
            AND head_fork_id = 1
    ), 'No alice1 STATE_CHANGED entry';

    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
                context_name = 'alice2'
            AND application_stage = 'a2stage2'
            AND event_type = 'STATE_CHANGED'
            AND application_block = 1
            AND application_fork = 1
            AND head_block  = 50
            AND head_fork_id = 1
    ), 'No alice2 STATE_CHANGED entry a2stage2';

    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
              context_name = 'alice2'
          AND application_stage = 'live'
          AND event_type = 'STATE_CHANGED'
          AND application_block = 50
          AND application_fork = 1
          AND head_block  = 50
          AND head_fork_id = 1
    ), 'No alice2 STATE_CHANGED entry live';
END;
$BODY$;