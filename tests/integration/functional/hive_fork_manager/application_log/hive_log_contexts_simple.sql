CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES
          ( 1, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 50, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 50)
    ;
    PERFORM hive.set_irreversible( 50 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __alice_stages hafd.application_stages :=
        ARRAY[ ('stage2',100 ,100 )::hafd.application_stage
            , ('stage1',10 ,10 )::hafd.application_stage
            , hafd.live_stage()
            ];
    __range_placeholder hive.blocks_range;
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( 'alice', 'alice', _stages => __alice_stages );
    CALL hive.app_next_iteration( ARRAY[ 'alice' ], __range_placeholder );
    PERFORM hive.app_create_context( 'alice_no_stages', 'alice' );
    UPDATE hafd.contexts SET current_block_num = 10 WHERE name = 'alice_no_stages';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- empty log for test
    TRUNCATE hafd.contexts_log;
    ALTER SEQUENCE hafd.contexts_log_id_seq RESTART WITH 1;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    RAISE NOTICE 'ALICE TEST WHEN!';
    PERFORM hive.log_context( 'alice', 'CREATED'::hafd.context_event );
    PERFORM hive.log_context( 'alice', 'ATTACHED'::hafd.context_event );
    PERFORM hive.log_context( 'alice', 'DETACHED'::hafd.context_event );
    PERFORM hive.log_context( 'alice', 'REMOVED'::hafd.context_event );
    PERFORM hive.log_context( 'alice', 'STATE_CHANGED'::hafd.context_event );

    PERFORM hive.log_context( 'alice_no_stages', 'CREATED'::hafd.context_event );
    PERFORM hive.log_context( 'alice_no_stages', 'ATTACHED'::hafd.context_event );
    PERFORM hive.log_context( 'alice_no_stages', 'DETACHED'::hafd.context_event );
    PERFORM hive.log_context( 'alice_no_stages', 'REMOVED'::hafd.context_event );
    PERFORM hive.log_context( 'alice_no_stages', 'STATE_CHANGED'::hafd.context_event );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
            id = 1
        AND context_name = 'alice'
        AND application_stage = 'stage1'
        AND event_type = 'CREATED'
        AND application_block = 10
        AND application_fork = 1
        AND head_block  = 50
        AND head_fork_id = 1
    ), 'No CREATED entry';

    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
          id = 2
          AND context_name = 'alice'
          AND application_stage = 'stage1'
          AND event_type = 'ATTACHED'
          AND application_block = 10
          AND application_fork = 1
          AND head_block  = 50
          AND head_fork_id = 1
    ), 'No ATTACHED entry';

    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
          id = 3
          AND context_name = 'alice'
          AND application_stage = 'stage1'
          AND event_type = 'DETACHED'
          AND application_block = 10
          AND application_fork = 1
          AND head_block  = 50
          AND head_fork_id = 1
    ), 'No DETACHED entry';

    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
          id = 4
          AND context_name = 'alice'
          AND application_stage = 'stage1'
          AND event_type = 'REMOVED'
          AND application_block = 10
          AND application_fork = 1
          AND head_block  = 50
          AND head_fork_id = 1
    ), 'No REMOVED entry';

    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
          id = 5
          AND context_name = 'alice'
          AND application_stage = 'stage1'
          AND event_type = 'STATE_CHANGED'
          AND application_block = 10
          AND application_fork = 1
          AND head_block  = 50
          AND head_fork_id = 1
    ), 'No STATE_CHANGED entry';

    -- ---------------------------------------
    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
                id = 6
                AND context_name = 'alice_no_stages'
                AND application_stage IS NULL
                AND event_type = 'CREATED'
                AND application_block = 10
                AND application_fork = 1
                AND head_block  = 50
                AND head_fork_id = 1
    ), 'No CREATED entry';

    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
            id = 7
            AND context_name = 'alice_no_stages'
            AND application_stage IS NULL
            AND event_type = 'ATTACHED'
            AND application_block = 10
            AND application_fork = 1
            AND head_block  = 50
            AND head_fork_id = 1
    ), 'No ATTACHED entry';

    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
            id = 8
            AND context_name = 'alice_no_stages'
            AND application_stage IS NULL
            AND event_type = 'DETACHED'
            AND application_block = 10
            AND application_fork = 1
            AND head_block  = 50
            AND head_fork_id = 1
    ), 'No DETACHED entry';

    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
            id = 9
            AND context_name = 'alice_no_stages'
            AND application_stage IS NULL
            AND event_type = 'REMOVED'
            AND application_block = 10
            AND application_fork = 1
            AND head_block  = 50
            AND head_fork_id = 1
    ), 'No REMOVED entry';

    ASSERT EXISTS(
        SELECT 1 FROM hafd.contexts_log WHERE
            id = 10
            AND context_name = 'alice_no_stages'
            AND application_stage IS NULL
            AND event_type = 'STATE_CHANGED'
            AND application_block = 10
            AND application_fork = 1
            AND head_block  = 50
            AND head_fork_id = 1
    ), 'No STATE_CHANGED entry';


END;
$BODY$
;





