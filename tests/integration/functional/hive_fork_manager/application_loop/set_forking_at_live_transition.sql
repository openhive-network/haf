-- An application that runs its massive sync on a non-forking context switches it to
-- forking on the first live-stage iteration (as haf_block_explorer and balance_tracker
-- do). At that moment the context's current_block_num usually trails
-- hive_state.consistent_block: with OBI the irreversible block rides at ~head, and a
-- from-genesis massive sync always terminates behind a moving head. The mode switch
-- must not move the context's position - every block between current_block_num and the
-- irreversible block must still be delivered to the application exactly once.
-- Regression test for issue #334 (root cause of haf_block_explorer#133, where
-- app_context_set_forking reattached the context at the irreversible block and the
-- backlog was silently skipped).
--
-- Scenario: 10 irreversible blocks, massive stage active while the distance to head is
-- at least 5, batches of 2. The loop delivers (1,2)(3,4)(5,6), then the re-analyze
-- inside the next iteration flips the stage to live and hands out (7,7) - so the first
-- live-stage iteration happens with the cursor at 7 while the irreversible block is
-- already 10: a live backlog at the switch, exactly like the incident.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __account hafd.accounts%ROWTYPE;
    __context_stages hafd.application_stages := ARRAY[ hive.stage( 'MASSIVE_PROCESSING', 5, 2 ), hafd.live_stage() ];
    __block INTEGER;
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'context', _schema => 'a', _is_forking => FALSE, _stages => __context_stages );

    -- delivered block ranges and the context position around the mode switch,
    -- recorded during 'when' and verified in 'then'
    CREATE TABLE A.delivered( first_block INTEGER, last_block INTEGER );
    CREATE TABLE A.switch_position( cursor_before INTEGER, cursor_after INTEGER );

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

    FOR __block IN 2 .. 10 LOOP
        PERFORM hive.push_block(
             ( __block, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , NULL
            , NULL
            , NULL
            , NULL
            , NULL
            , NULL
        );
    END LOOP;
    PERFORM hive.set_irreversible( 10 );

    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( 10 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
    __cursor_before INTEGER;
    __cursor_after INTEGER;
    __switched BOOLEAN := FALSE;
    __iteration INTEGER;
BEGIN
    FOR __iteration IN 1 .. 20 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks );

        IF __blocks IS NOT NULL THEN
            INSERT INTO A.delivered VALUES( __blocks.first_block, __blocks.last_block );
        END IF;

        IF NOT __switched AND hive.get_current_stage_name( 'context' ) = 'live' THEN
            -- the application switches its context to forking on the first live-stage
            -- iteration, exactly as haf_block_explorer does - with the cursor still
            -- behind the irreversible block
            SELECT current_block_num INTO __cursor_before FROM hafd.contexts WHERE name = 'context';
            PERFORM hive.app_context_set_forking( 'context' );
            SELECT current_block_num INTO __cursor_after FROM hafd.contexts WHERE name = 'context';
            INSERT INTO A.switch_position VALUES( __cursor_before, __cursor_after );

            __switched := TRUE;
        END IF;

        EXIT WHEN __switched AND __blocks IS NULL
            AND ( SELECT current_block_num FROM hafd.contexts WHERE name = 'context' ) >= 10;
    END LOOP;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __cursor_before INTEGER;
    __cursor_after INTEGER;
    __missing INTEGER;
    __duplicated INTEGER;
BEGIN
    SELECT cursor_before, cursor_after INTO __cursor_before, __cursor_after FROM A.switch_position;
    ASSERT __cursor_before IS NOT NULL, 'The mode switch was never performed';
    ASSERT __cursor_after = __cursor_before,
        FORMAT( 'app_context_set_forking moved the context position from %s to %s', __cursor_before, __cursor_after );

    SELECT COUNT(*) INTO __missing
    FROM generate_series( 1, 10 ) AS b( num )
    WHERE NOT EXISTS ( SELECT 1 FROM A.delivered d WHERE b.num BETWEEN d.first_block AND d.last_block );
    ASSERT __missing = 0, FORMAT( '%s block(s) were never delivered to the application', __missing );

    SELECT COUNT(*) INTO __duplicated
    FROM generate_series( 1, 10 ) AS b( num )
    WHERE ( SELECT COUNT(*) FROM A.delivered d WHERE b.num BETWEEN d.first_block AND d.last_block ) > 1;
    ASSERT __duplicated = 0, FORMAT( '%s block(s) were delivered more than once', __duplicated );

    ASSERT ( SELECT is_forking FROM hafd.contexts WHERE name = 'context' ) = TRUE, 'Context is not forking after the switch';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'context' ) = 10, 'Context did not reach the head block';
    ASSERT hive.app_context_is_attached( 'context' ) = TRUE, 'Context is not attached';
END;
$BODY$
;
