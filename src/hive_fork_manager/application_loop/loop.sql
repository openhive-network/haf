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
BEGIN
    UPDATE hive.contexts ctx
    SET  loop.current_stage = stages.stage
    FROM hive.get_current_stage( _contexts ) as stages
    WHERE ctx.name = stages.context;

    -- now is time to find number of blocks in one batch to process
    --TODO(mickiewicz@syncad.com): test for when all contexts are in live
    UPDATE hive.contexts ctx
    SET   loop.size_of_blocks_batch = max_limit.blocks
      , loop.end_block_range = ctx.current_block_num + __number_of_blocks_to_sync
      , loop.last_analyze_distance_to_head_block = COALESCE( _head_block, 0 ) - COALESCE( (ctx.loop).current_batch_end, 0 )
    FROM (
             SELECT MAX( (hc.loop).current_stage.blocks_limit_in_group )  as blocks
             FROM hive.contexts hc
             WHERE hc.name = ANY( _contexts )
         ) as max_limit
    WHERE ctx.name = ANY( _contexts );
END;
$body$;

CREATE OR REPLACE FUNCTION hive.is_stages_analyze_required(
          _lead_context_state hive.application_loop_state
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
          -- end of range processing
       OR _lead_context_state.end_block_range <= _lead_context_state.current_batch_end
          -- distance to head block grew instead become smaller
       OR _lead_context_state.last_analyze_distance_to_head_block > ( _current_head_block - _lead_context_state.current_batch_end );
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
    FROM hive.contexts hc
    WHERE hc.name = ANY(_contexts)
        AND (hc.loop).current_stage = hive.live_stage()
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
    FROM hive.blocks hb
    INTO __result;

    RETURN __result;
END;
$body$;

CREATE OR REPLACE FUNCTION hive.get_current_stage_name( _context hive.context_name )
    RETURNS hive.stage_name
    LANGUAGE 'plpgsql'
    STABLE
AS
$body$
DECLARE
    __result hive.stage_name;
BEGIN
    -- when context name is wrong an exception will be thrown
    -- NULL result means that state is not known yet
    SELECT (ctx.loop).current_stage.name INTO __result
    FROM hive.contexts ctx
    WHERE ctx.id = hive.get_context_id( _context );

    RETURN __result;
END;
$body$;

CREATE OR REPLACE PROCEDURE hive.app_next_iteration( _contexts hive.contexts_group, _blocks_range OUT hive.blocks_range )
LANGUAGE 'plpgsql'
AS
$body$
DECLARE
    __lead_context_name hive.context_name := _contexts[ 1 ];
    __lead_context_state hive.application_loop_state;
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );
    _blocks_range := NULL;

    -- here is the only place when main synchronization connection  makes commit
    -- 1. commit if there is a pending commit
    IF pg_current_xact_id_if_assigned() IS NOT NULL THEN
        COMMIT;
    END IF;

    SELECT (hc.loop).* INTO __lead_context_state
    FROM hive.contexts hc WHERE hc.name = __lead_context_name;

    RAISE INFO 'MICKIEWICZ Lead context state: %', __lead_context_state;

    -- 2. find current stage if:
    IF hive.is_stages_analyze_required( __lead_context_state, hive.get_irreversible_head_block() )
    THEN
        IF hive.is_abs_livesync( _contexts )
           AND NOT hive.app_context_are_attached( _contexts )
        THEN
            PERFORM hive.app_context_attach( _contexts );
        END IF;
        SELECT * FROM hive.app_next_block( _contexts ) INTO _blocks_range;
        IF _blocks_range IS NULL
        THEN
            RAISE INFO 'MICKIEWICZ no range';
            RETURN;
        END IF;
        -- all context now got computed their stages
        RAISE NOTICE 'MICKIEWICZ range %', _blocks_range;
        PERFORM hive.analyze_stages( _contexts, _blocks_range,hive.get_irreversible_head_block() );
        SELECT (hc.loop).* INTO __lead_context_state
        FROM hive.contexts hc WHERE hc.name = __lead_context_name;

        RAISE INFO 'Updated lead contex: %', __lead_context_state;
    ELSE
        -- we continue iterating blocks in range
        _blocks_range.first_block = __lead_context_state.current_batch_end + 1;
    END IF;

    _blocks_range.last_block = LEAST(
          _blocks_range.first_block + __lead_context_state.size_of_blocks_batch - 1
        , __lead_context_state.end_block_range
    );

    RAISE INFO 'MICKIEWICZ Returned blocks range %', _blocks_range;

    UPDATE hive.contexts ctx
    SET loop.current_batch_end = _blocks_range.last_block
    WHERE ctx.name=ANY(_contexts);

    PERFORM hive.update_attachment( _contexts );

    UPDATE hive.contexts ctx
    SET current_block_num = _blocks_range.last_block --TODO(mickiewicz@syncad.com) hmm zmien nazwe na current batch begin
    WHERE ctx.name = ANY(_contexts);

    -- 4. returns range of blocks to process together with context stages
END;
$body$;
