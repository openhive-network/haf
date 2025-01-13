CREATE OR REPLACE FUNCTION hive.set_waiting_for_haf_stage(
    _contexts hive.contexts_group
)
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __placeholder BOOL;
BEGIN
    WITH updated_fun AS (
        UPDATE hafd.contexts ctx
            SET loop.current_stage = hafd.wait_for_haf_stage()
            WHERE ctx.name = ANY(_contexts)
            AND ( (ctx.loop).current_stage != hafd.wait_for_haf_stage() OR (ctx.loop).current_stage IS NULL)
            RETURNING hive.log_context( ctx.name, 'STATE_CHANGED'::hafd.context_event )
    ) SELECT True INTO __placeholder; -- workaround for forbidden PERFORM with CTE UPDATE
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.analyze_stages(
      _contexts hive.contexts_group
    , _blocks_range hive.blocks_range
    , _head_block INTEGER
)
RETURNS void
LANGUAGE 'plpgsql'
VOLATILE
AS
$body$
DECLARE
    __number_of_blocks_to_sync INTEGER := (_blocks_range.last_block - _blocks_range.first_block);
    __placeholder BOOL;
BEGIN
    WITH updated_fun AS (
        UPDATE hafd.contexts ctx
        SET loop.current_stage = stages.stage
        FROM hive.get_current_stage(_contexts) as stages
        WHERE ctx.name = stages.context
        AND ( (ctx.loop).current_stage != stages.stage OR (ctx.loop).current_stage IS NULL)
        RETURNING hive.log_context( ctx.name, 'STATE_CHANGED'::hafd.context_event )
    ) SELECT True INTO __placeholder; -- workaround for forbidden PERFORM with CTE UPDATE


    -- now is time to find number of blocks in one batch to process
    UPDATE hafd.contexts ctx
    SET   loop.size_of_blocks_batch = COALESCE(max_limit.blocks,1)
      , loop.end_block_range = ctx.current_block_num + __number_of_blocks_to_sync
      , loop.last_analyze_distance_to_head_block = COALESCE( _head_block, 0 ) - COALESCE( (ctx.loop).current_batch_end, 0 )
    FROM (
             SELECT MIN( (hc.loop).current_stage.blocks_limit_in_group )  as blocks
             FROM hafd.contexts hc
             WHERE hc.name = ANY( _contexts ) AND (hc.loop).current_stage != hafd.live_stage()
         ) as max_limit
    WHERE ctx.name = ANY( _contexts );
END;
$body$;

CREATE OR REPLACE FUNCTION hive.is_stages_analyze_required(
          _lead_context_state hafd.application_loop_state
        , _current_head_block INTEGER
)
    RETURNS BOOL
    LANGUAGE 'plpgsql'
    IMMUTABLE
AS
$body$
BEGIN
    RETURN
          -- we did not start any iteration
          _lead_context_state IS NULL
          -- we are in wait_for_haf stage
       OR _lead_context_state.current_stage = hafd.wait_for_haf_stage()
          -- end of range processing
       OR _lead_context_state.end_block_range <= _lead_context_state.current_batch_end
          -- distance to head block grew instead become smaller
       OR _lead_context_state.last_analyze_distance_to_head_block < ( _current_head_block - _lead_context_state.current_batch_end );
END;
$body$;

CREATE OR REPLACE FUNCTION hive.is_livesync( _contexts hive.contexts_group )
    RETURNS BOOL
    LANGUAGE 'plpgsql'
    STABLE
AS
$body$
DECLARE
    __result BOOLEAN := FALSE;
BEGIN
    -- livesync only when all stages are livesync
    SELECT ( COUNT(*) = CARDINALITY(_contexts) ) INTO __result
    FROM hafd.contexts hc
    WHERE hc.name = ANY(_contexts)
        AND (hc.loop).current_stage = hafd.live_stage()
    ;

    RETURN __result;
END;
$body$;

CREATE OR REPLACE FUNCTION hive.update_attachment( _contexts hive.contexts_group )
    RETURNS VOID
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$body$
BEGIN
    IF hive.is_livesync(_contexts)
    THEN -- ensures that contexts are attached
        IF NOT hive.app_context_are_attached( _contexts )
        THEN
            PERFORM hive.app_context_attach( _contexts );
        END IF;
    ELSE -- ensures that contexts are detached
        IF hive.app_context_are_attached( _contexts )
        THEN
            PERFORM hive.app_context_detach( _contexts );
        END IF;
    END IF;
END;
$body$;

CREATE OR REPLACE FUNCTION hive.get_irreversible_head_block()
    RETURNS INTEGER
    LANGUAGE 'plpgsql'
    STABLE
AS
$body$
DECLARE
    __result INTEGER;
BEGIN
    SELECT COALESCE( MAX(hb.num), 0 )
    FROM hafd.blocks hb
    INTO __result;

    RETURN __result;
END;
$body$;

CREATE OR REPLACE FUNCTION hive.get_current_stage_name( _context hafd.context_name )
    RETURNS hafd.stage_name
    LANGUAGE 'plpgsql'
    STABLE
AS
$body$
DECLARE
    __result hafd.stage_name;
BEGIN
    -- when context name is wrong an exception will be thrown
    -- NULL result means that state is not known yet
    SELECT (ctx.loop).current_stage.name INTO __result
    FROM hafd.contexts ctx
    WHERE ctx.id = hive.get_context_id( _context );

    RETURN __result;
END;
$body$;

CREATE OR REPLACE PROCEDURE hive.app_next_iteration( _contexts hive.contexts_group, _blocks_range OUT hive.blocks_range, _override_max_batch INTEGER = NULL, _limit INTEGER = NULL )
LANGUAGE 'plpgsql'
AS
$body$
DECLARE
    __lead_context_name hafd.context_name := _contexts[ 1 ];
    __lead_context_state hafd.application_loop_state;
    __now TIMESTAMP := NOW();
    __previous_active_at_time TIMESTAMP;
BEGIN
    -- here is the only place when main synchronization connection  makes commit
    -- 1. commit if there is a pending commit
    IF pg_current_xact_id_if_assigned() IS NOT NULL THEN
        COMMIT;
    END IF;

    SELECT last_active_at INTO __previous_active_at_time
    FROM hafd.contexts  WHERE name = __lead_context_name;

    PERFORM hive.app_check_contexts_synchronized( _contexts );
    _blocks_range := NULL;

    UPDATE hafd.contexts ctx
    SET last_active_at = __now
    WHERE ctx.name = ANY(_contexts);

    IF _limit IS NOT NULL
    THEN
        IF hive.app_get_current_block_num( __lead_context_name ) >= _limit THEN
            RETURN;
        END IF;
    END IF;

    IF NOT hive.is_instance_ready() THEN
        PERFORM hive.set_waiting_for_haf_stage( _contexts );
        PERFORM pg_sleep( 0.5 );
        RETURN;
    END IF;

    ASSERT _override_max_batch IS NULL OR _override_max_batch > 0, 'Custom size of  blocks range is less than 1';

    IF EXISTS( SELECT 1 FROM hafd.contexts hc WHERE hc.name = ANY(_contexts) AND hc.stages = NULL )
    THEN
        RAISE EXCEPTION 'Some contexts from group % have no stages defined and cannot be used with hive.app_next_iteration', _contexts;
    END IF;

    SELECT (hc.loop).* INTO __lead_context_state
    FROM hafd.contexts hc WHERE hc.name = __lead_context_name;

    IF __lead_context_state IS NOT NULL
      AND ( __now - __previous_active_at_time ) >= (__lead_context_state).current_stage.processing_alarm_threshold
    THEN
        -- only lead context is reported
        PERFORM hive.log_context( __lead_context_name, 'SLOW_PROCESSING'::hafd.context_event );
    END IF;

    -- 2. find current stage if:
    IF hive.is_stages_analyze_required( __lead_context_state, hive.get_irreversible_head_block() )
    THEN
        -- get lock to synchronize with potentially running autodetach
        PERFORM  1 FROM hafd.contexts c WHERE c.name = ANY(_contexts) FOR UPDATE;

        IF NOT hive.app_context_are_attached( _contexts )
        THEN
            PERFORM hive.app_context_attach( _contexts );
        END IF;

        SELECT * FROM hive.app_next_block( _contexts ) INTO _blocks_range;
        IF _blocks_range IS NULL
        THEN
            RETURN;
        END IF;

        -- all context now got computed their stages
        PERFORM hive.analyze_stages( _contexts, _blocks_range,hive.get_irreversible_head_block() );
        SELECT (hc.loop).* INTO __lead_context_state
        FROM hafd.contexts hc WHERE hc.name = __lead_context_name;
    ELSE
        -- we continue iterating blocks in range
        _blocks_range.first_block = __lead_context_state.current_batch_end + 1;
    END IF;

    IF _override_max_batch IS NOT NULL
    THEN
        _blocks_range.last_block := LEAST(
              _blocks_range.first_block + _override_max_batch - 1
            , __lead_context_state.end_block_range
        );
    ELSE
        _blocks_range.last_block = LEAST(
              _blocks_range.first_block + __lead_context_state.size_of_blocks_batch - 1
            , __lead_context_state.end_block_range
        );
    END IF;

    IF _limit IS NOT NULL
    THEN
        _blocks_range.last_block = LEAST(
              _blocks_range.last_block
            , _limit
        );
    END IF;

    UPDATE hafd.contexts ctx
    SET loop.current_batch_end = _blocks_range.last_block
    WHERE ctx.name=ANY(_contexts);

    PERFORM hive.update_attachment( _contexts );

    UPDATE hafd.contexts ctx
    SET current_block_num = _blocks_range.last_block
    WHERE ctx.name = ANY(_contexts);
END;
$body$;

CREATE OR REPLACE PROCEDURE hive.app_next_iteration( _context hafd.context_name, _blocks_range OUT hive.blocks_range, _override_max_batch INTEGER = NULL, _limit INTEGER = NULL )
    LANGUAGE 'plpgsql'
AS
$body$
BEGIN
    CALL hive.app_next_iteration( ARRAY[ _context ], _blocks_range, _override_max_batch, _limit );
END;
$body$;
