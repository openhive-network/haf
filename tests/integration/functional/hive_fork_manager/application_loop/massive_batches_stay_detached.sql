-- A forking context that is several massive batches behind the head stays detached from one
-- stage analysis to the next: its attachment changes only when its stage changes. Attaching
-- it before each analysis, only for hive.update_attachment to detach it again, recreated its
-- views and shadow-table triggers at every batch boundary and deadlocked other sessions
-- reading them.
--
-- Scenario: 10 irreversible blocks, then three more rounds of 10 blocks, each fed (with the
-- mocked head advanced) when the context has drained the previous range, so every round
-- starts with a stage analysis that keeps the massive stage (distance 9 >= 5). A last round of
-- 3 blocks makes the analysis select live (distance 2 < 5).

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __account hafd.accounts%ROWTYPE;
    __context_stages hafd.application_stages := ARRAY[ hive.stage( 'MASSIVE_PROCESSING', 5, 3 ), hafd.live_stage() ];
    __block INTEGER;
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'context', _schema => 'a', _stages => __context_stages );
    CREATE TABLE A.table1( id INTEGER ) INHERITS( a.context );

    -- delivered block ranges and the end of the analyzed range after each iteration,
    -- recorded during 'when' and verified in 'then'
    CREATE TABLE A.delivered( first_block INTEGER, last_block INTEGER );
    CREATE TABLE A.analyzed_ranges( stage hafd.stage_name, end_block_range INTEGER );

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
             ( __block, ('\xBADD' || lpad( __block::TEXT, 2, '0' ))::bytea, '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , NULL, NULL, NULL, NULL, NULL, NULL
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
    __head INTEGER := 10;
    __rounds INTEGER[] := ARRAY[ 10, 10, 10, 3 ];
    __round INTEGER := 1;
    __iteration INTEGER;
    __block INTEGER;
BEGIN
    -- the update variant re-creates hive.get_estimated_hive_head_block() after 'given',
    -- which drops the mock
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( __head );

    FOR __iteration IN 1 .. 60 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks );

        IF __blocks IS NOT NULL THEN
            INSERT INTO A.delivered VALUES( __blocks.first_block, __blocks.last_block );
        END IF;

        INSERT INTO A.analyzed_ranges
        SELECT (hc.loop).current_stage.name, (hc.loop).end_block_range FROM hafd.contexts hc WHERE hc.name = 'context';

        -- feed the next round once the current range is drained, before the next analysis
        IF __round <= CARDINALITY( __rounds )
           AND ( SELECT current_block_num FROM hafd.contexts WHERE name = 'context' ) >= __head THEN
            FOR __block IN __head + 1 .. __head + __rounds[ __round ] LOOP
                PERFORM hive.push_block(
                     ( __block, ('\xBADD' || lpad( __block::TEXT, 2, '0' ))::bytea, '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                    , NULL, NULL, NULL, NULL, NULL, NULL
                );
            END LOOP;
            __head := __head + __rounds[ __round ];
            PERFORM hive.set_irreversible( __head );
            PERFORM test.set_head_block_num( __head );
            __round := __round + 1;
        END IF;

        EXIT WHEN __round > CARDINALITY( __rounds ) AND __blocks IS NULL
            AND ( SELECT current_block_num FROM hafd.contexts WHERE name = 'context' ) >= __head;
    END LOOP;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __massive_analyses INTEGER;
    __events TEXT[];
    __missing INTEGER;
    __duplicated INTEGER;
BEGIN
    SELECT COUNT( DISTINCT end_block_range ) INTO __massive_analyses
    FROM A.analyzed_ranges WHERE stage = 'MASSIVE_PROCESSING';
    ASSERT __massive_analyses >= 4, FORMAT( 'Only %s stage analyses in the massive stage', __massive_analyses );

    -- the context is created detached and attached for its first analysis, which selects the
    -- massive stage and detaches it; it is attached again only when an analysis selects live
    SELECT ARRAY_AGG( log.event_type::TEXT || ':' || COALESCE( log.application_stage::TEXT, '' ) ORDER BY log.id ) INTO __events
    FROM hafd.contexts_log log
    WHERE log.context_name = 'context'
      AND log.event_type IN ( 'ATTACHED', 'DETACHED', 'STATE_CHANGED' );
    ASSERT __events = ARRAY[
          'ATTACHED:'
        , 'STATE_CHANGED:MASSIVE_PROCESSING'
        , 'DETACHED:MASSIVE_PROCESSING'
        , 'STATE_CHANGED:live'
        , 'ATTACHED:live'
    ], FORMAT( 'Wrong contexts_log sequence %s', __events );

    SELECT COUNT(*) INTO __missing
    FROM generate_series( 1, 43 ) AS b( num )
    WHERE NOT EXISTS ( SELECT 1 FROM A.delivered d WHERE b.num BETWEEN d.first_block AND d.last_block );
    ASSERT __missing = 0, FORMAT( '%s block(s) were never delivered to the application', __missing );

    SELECT COUNT(*) INTO __duplicated
    FROM generate_series( 1, 43 ) AS b( num )
    WHERE ( SELECT COUNT(*) FROM A.delivered d WHERE b.num BETWEEN d.first_block AND d.last_block ) > 1;
    ASSERT __duplicated = 0, FORMAT( '%s block(s) were delivered more than once', __duplicated );

    ASSERT hive.get_current_stage_name( 'context' ) = 'live', 'Context did not reach the live stage';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'context' ) = 43, 'Context did not reach the head block';
    ASSERT hive.app_context_is_attached( 'context' ) = TRUE, 'Context is not attached';
END;
$BODY$
;
