-- hive.remove_unecessary_events removes the events below both the first event of the block after the
-- new irreversible block and the lowest events_id of the contexts, never the special events 0 and
-- hive.unreachable_event_id(), and reads hafd.contexts once per call.

-- Rebuilds the queue as ids 1..10 = NEW_BLOCK of blocks 1..10 and id 11 = BACK_FROM_FORK of fork 6
-- (its block_num is the fork id), plus the special events; adds one context per element of
-- _contexts_events_ids; runs hive.remove_unecessary_events( _new_irreversible_block ) and returns the
-- ids left in the queue. Everything is rolled back afterwards.
CREATE OR REPLACE FUNCTION public.events_left( _contexts_events_ids BIGINT[], _new_irreversible_block INT )
RETURNS BIGINT[]
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __left BIGINT[];
BEGIN
    BEGIN
        DELETE FROM hafd.events_queue WHERE id != 0 AND id != hive.unreachable_event_id();
        INSERT INTO hafd.events_queue( id, event, block_num )
        SELECT i, 'NEW_BLOCK', i FROM generate_series( 1, 10 ) i;
        INSERT INTO hafd.events_queue( id, event, block_num ) VALUES ( 11, 'BACK_FROM_FORK', 6 );

        INSERT INTO hafd.contexts( name, schema, current_block_num, irreversible_block, owner, last_active_at, baseclass_id, events_id )
        SELECT 'ctx_' || ord, 'ctx_' || ord, 0, 0, 'events_test', NOW(), 'hafd.contexts'::REGCLASS, events_id
        FROM unnest( _contexts_events_ids ) WITH ORDINALITY AS c( events_id, ord );

        PERFORM hive.remove_unecessary_events( _new_irreversible_block );

        SELECT array_agg( id ORDER BY id ) INTO __left FROM hafd.events_queue;
        RAISE EXCEPTION USING ERRCODE = 'P0099';
    EXCEPTION WHEN SQLSTATE 'P0099' THEN
        -- rolls the case back
    END;
    RETURN __left;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION public.assert_events_left( _case TEXT, _contexts_events_ids BIGINT[], _new_irreversible_block INT, _expected BIGINT[] )
RETURNS VOID
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __left BIGINT[] := public.events_left( _contexts_events_ids, _new_irreversible_block );
BEGIN
    ASSERT __left = _expected, format( '%s: events left %s, expected %s', _case, __left, _expected );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hafd.contexts ) = 0, 'test expects no contexts';
    ASSERT ( SELECT array_agg( id ORDER BY id ) FROM hafd.events_queue ) = ARRAY[ 0, hive.unreachable_event_id() ]
        , 'test expects only the special events';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __u BIGINT := hive.unreachable_event_id();
    __scans_before BIGINT;
    __events_before BIGINT;
    __scans BIGINT;
    __deleted BIGINT;
BEGIN
    -- the first event of block 6 is id 6; the BACK_FROM_FORK event of fork 6 does not count
    PERFORM public.assert_events_left( 'no contexts', ARRAY[]::BIGINT[], 5
        , ARRAY[ 0, 6, 7, 8, 9, 10, 11, __u ] );
    PERFORM public.assert_events_left( 'contexts behind the irreversible block', ARRAY[ 8, 3 ], 5
        , ARRAY[ 0, 3, 4, 5, 6, 7, 8, 9, 10, 11, __u ] );
    PERFORM public.assert_events_left( 'contexts ahead of the irreversible block', ARRAY[ 9, 8 ], 5
        , ARRAY[ 0, 6, 7, 8, 9, 10, 11, __u ] );
    PERFORM public.assert_events_left( 'all contexts detached', ARRAY[ __u, __u ], 5
        , ARRAY[ 0, 6, 7, 8, 9, 10, 11, __u ] );
    PERFORM public.assert_events_left( 'a context that processed no event', ARRAY[ 0, 9 ], 5
        , ARRAY[ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, __u ] );
    PERFORM public.assert_events_left( 'a context without events_id', ARRAY[ NULL, 4 ], 5
        , ARRAY[ 0, 4, 5, 6, 7, 8, 9, 10, 11, __u ] );
    -- no event for block 21: no upper bound
    PERFORM public.assert_events_left( 'no upper bound', ARRAY[ 8, __u ], 20
        , ARRAY[ 0, 8, 9, 10, 11, __u ] );
    PERFORM public.assert_events_left( 'no upper bound and no contexts', ARRAY[]::BIGINT[], 20
        , ARRAY[ 0, __u ] );
    PERFORM public.assert_events_left( 'no upper bound and all contexts detached', ARRAY[ __u ], 20
        , ARRAY[ 0, __u ] );

    -- hafd.contexts is scanned once for the lowest events_id, plus once by the fk_hive_app_context
    -- check of each removed event, also under the generic plan that used to re-scan it per event
    SET LOCAL plan_cache_mode = force_generic_plan;
    INSERT INTO hafd.events_queue( id, event, block_num )
    SELECT i, 'NEW_BLOCK', i FROM generate_series( 1, 50 ) i;
    INSERT INTO hafd.contexts( name, schema, current_block_num, irreversible_block, owner, last_active_at, baseclass_id, events_id )
    VALUES ( 'ctx', 'ctx', 0, 0, 'events_test', NOW(), 'hafd.contexts'::REGCLASS, 40 );
    SELECT COUNT(*) INTO __events_before FROM hafd.events_queue;
    SELECT seq_scan + COALESCE( idx_scan, 0 ) INTO __scans_before FROM pg_stat_xact_user_tables WHERE relid = 'hafd.contexts'::REGCLASS;

    PERFORM hive.remove_unecessary_events( 45 );

    SELECT seq_scan + COALESCE( idx_scan, 0 ) - __scans_before INTO __scans FROM pg_stat_xact_user_tables WHERE relid = 'hafd.contexts'::REGCLASS;
    __deleted := __events_before - ( SELECT COUNT(*) FROM hafd.events_queue );
    ASSERT __deleted = 39, format( 'removed %s events, expected 39', __deleted );
    ASSERT __scans = 1 + __deleted, format( 'hafd.contexts scanned %s times for %s removed events', __scans, __deleted );
END;
$BODY$
;
