CREATE OR REPLACE FUNCTION hive.find_next_event( _contexts hive.contexts_group )
    RETURNS hive.events_queue
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __curent_events_id hive.events_queue.id%TYPE;
    __newest_irreversible_block_num hive.blocks.num%TYPE;
    __current_context_block_num hive.blocks.num%TYPE;
    __current_context_irreversible_block hive.blocks.num%TYPE;
    __lead_context hive.context_name := _contexts[ 1 ];
    __result hive.events_queue%ROWTYPE;
BEGIN
    SELECT hc.events_id
         , hc.current_block_num
         , hc.irreversible_block
    INTO __curent_events_id, __current_context_block_num, __current_context_irreversible_block
    FROM hive.contexts hc WHERE hc.name = __lead_context;
    SELECT consistent_block INTO __newest_irreversible_block_num FROM hive.irreversible_data;
    IF __current_context_block_num <= __current_context_irreversible_block  AND  __newest_irreversible_block_num IS NOT NULL THEN
        -- here we are sure that context only processing irreversible blocks, we can continue
        -- processing irreversible blocks or find next event after irreversible
        SELECT * INTO  __result
        FROM hive.events_queue heq
        WHERE heq.block_num > __newest_irreversible_block_num
              AND heq.event != 'BACK_FROM_FORK'
              AND heq.id >= __curent_events_id
              AND heq.id != hive.unreachable_event_id()
        ORDER BY heq.id LIMIT 1
        FOR UPDATE;

        IF __result IS NULL THEN
            -- there is no reversible blocks event
            -- the last possible event are MASSIVE_SYNC(__newest_irreversible_block_num) or NEW_IRREVERSIBLE(__newest_irreversible_block_num)
            SELECT * INTO  __result
            FROM hive.events_queue heq
            WHERE heq.block_num = __newest_irreversible_block_num
              AND ( heq.event = 'MASSIVE_SYNC' OR heq.event = 'NEW_IRREVERSIBLE' )
              AND heq.id != hive.unreachable_event_id()
            ORDER BY heq.id LIMIT 1
            FOR UPDATE;

            IF __result IS NOT NULL AND __result.id = __curent_events_id THEN
                -- when there is no event than recently processed
                RETURN NULL;
            END IF;
        END IF;

        UPDATE hive.contexts
        SET irreversible_block = __newest_irreversible_block_num WHERE name =ANY( _contexts );
    ELSE
        ---- find next event
        SELECT * INTO __result
        FROM hive.events_queue heq
        WHERE heq.id > __curent_events_id AND heq.id != hive.unreachable_event_id()
        ORDER BY id LIMIT 1
        FOR UPDATE;
    END IF;

    IF __result IS NOT NULL THEN
        UPDATE hive.contexts
        SET events_id = __result.id
        WHERE name =ANY( _contexts );
    END IF;

    RETURN __result;
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.squash_fork_events( _contexts hive.contexts_group )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __next_fork_event_id BIGINT;
    __next_fork_block_num INT;
    __context_current_block_num INT;
    __context_id hive.contexts.id%TYPE;
    __cannot_jump BOOL:= TRUE;
    __lead_context hive.context_name := _contexts[ 1 ];
BEGIN
    -- first find a newer fork nearest current block
    SELECT heq.id, heq.block_num, hc.current_block_num, hc.id INTO __next_fork_event_id, __next_fork_block_num, __context_current_block_num, __context_id
    FROM hive.events_queue heq
    JOIN hive.fork hf ON hf.id = heq.block_num
    JOIN hive.contexts hc ON hc.events_id < heq.id AND hc.current_block_num >= hf.block_num
    WHERE heq.event = 'BACK_FROM_FORK' AND hc.name = __lead_context
    ORDER BY hf.block_num ASC, heq.id DESC
    LIMIT 1
    FOR UPDATE OF hive.events_queue
    ;

    -- no newer fork, nothing to do
    IF __next_fork_event_id IS NULL THEN
        RETURN;
    END IF;

    -- there may be NEW_IRREVERSIBLE or MASSIVE_SYNC in the range
    SELECT EXISTS (
        SELECT 1
        FROM hive.events_queue heq
        JOIN hive.contexts hc ON heq.id < __next_fork_event_id AND heq.id > hc.events_id
        WHERE ( heq.event = 'NEW_IRREVERSIBLE' OR heq.event = 'MASSIVE_SYNC' ) AND hc.name = _contexts[1]
        FOR UPDATE OF hive.events_queue
    )
    INTO __cannot_jump;

    IF __cannot_jump THEN
        RETURN;
    END IF;

    UPDATE hive.contexts
    SET events_id = __next_fork_event_id - 1 -- -1 because we pretend that we stay just before the next fork
    WHERE name =ANY(_contexts);
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.squash_end_massive_sync_events( _contexts hive.contexts_group )
    RETURNS BOOL
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __next_massive_sync_event_id BIGINT;
    __context_current_block_num INT;
    __context_id hive.contexts.id%TYPE;
    __irreversible_block_num INT;
    __before_next_massive_sync_event_id BIGINT := NULL;
    __lead_context hive.context_name := _contexts[ 1 ];
BEGIN
    -- first find a newer massive_sync nearest current block
    SELECT heq.id, hc.current_block_num, hc.id, hc.irreversible_block
    INTO __next_massive_sync_event_id, __context_current_block_num, __context_id, __irreversible_block_num
    FROM hive.events_queue heq
    JOIN hive.contexts hc ON COALESCE( hc.events_id, 1 ) < heq.id -- 1 because we don't want squash only the first event
    WHERE heq.event = 'MASSIVE_SYNC' AND hc.name = _contexts[1]
    ORDER BY heq.id DESC
    LIMIT 1
    FOR UPDATE OF hive.events_queue
    ;

    SELECT hc.current_block_num
    INTO __context_current_block_num
    FROM hive.contexts hc
    WHERE hc.name = __lead_context
    ;

    -- no newer MASSIVE_SYNC, nothing to do
    IF __next_massive_sync_event_id IS NULL THEN
            RETURN FALSE;
    END IF;

    -- TODO(@Mickiewicz): hmm big problem, all contexts need to do this
    -- back form fork is required
    PERFORM hive.context_back_from_fork( ctx.*, __irreversible_block_num ) FROM unnest(_contexts) ctx;

    SELECT MAX( heq.id ) INTO __before_next_massive_sync_event_id
    FROM hive.events_queue heq WHERE heq.id < __next_massive_sync_event_id
    FOR UPDATE;

    UPDATE hive.contexts
    SET events_id = __before_next_massive_sync_event_id -- it may be null if there is no events before the massive sync
    WHERE name =ANY( _contexts );
    RETURN TRUE;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.squash_events( _contexts hive.contexts_group )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __current_event_id hive.events_queue.id%TYPE;
BEGIN
    SELECT hc.events_id INTO __current_event_id FROM hive.contexts hc WHERE hc.name = _contexts[ 1 ];

    -- do not squash not initialzed context
    IF __current_event_id = 0  THEN
            RETURN;
    END IF;

    IF NOT hive.squash_end_massive_sync_events( _contexts ) THEN
        PERFORM hive.squash_fork_events( _contexts );
    END IF;
END;
$BODY$
;

DROP TYPE IF EXISTS hive.blocks_range CASCADE;
CREATE TYPE hive.blocks_range AS (
    first_block INT
    , last_block INT
    );


DROP TYPE IF EXISTS hive.context_state CASCADE;
CREATE TYPE hive.context_state AS (
      current_block_num INT
    , is_attached BOOL
    , irreversible_block_num INT
    , next_event_id BIGINT
    , next_event_type hive.event_type
    , next_event_block_num INT
);



CREATE OR REPLACE FUNCTION hive.squash_and_get_state( _contexts hive.contexts_group )
    RETURNS hive.context_state
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
    DECLARE
        __context_state hive.context_state;
        __lead_context hive.context_name := _contexts[ 1 ];
    BEGIN
        PERFORM hive.squash_events( _contexts );

        SELECT
               hac.current_block_num
             , hac.is_attached
             , hac.irreversible_block
        FROM hive.contexts hac
        WHERE hac.name = __lead_context
        INTO __context_state;

        IF __context_state.current_block_num IS NULL THEN
            RAISE EXCEPTION 'No context with name %', __lead_context;
        END IF;

        IF __context_state.is_attached = FALSE THEN
            RAISE EXCEPTION 'Context % is detached', __lead_context;
        END IF;

        SELECT * INTO __context_state.next_event_id, __context_state.next_event_type,  __context_state.next_event_block_num
        FROM hive.find_next_event( _contexts );

        RETURN __context_state;
    END;
$BODY$
;

-- Returns
-- Null -> ask again without waiting
-- negative range -> no block to process, need to wait for next live block
-- positive range (including 0 size) -> range of blocks to process
CREATE OR REPLACE FUNCTION hive.app_process_event( _context TEXT, _context_state hive.context_state )
    RETURNS hive.blocks_range
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __next_block_to_process INT;
    __last_block_to_process INT;
    __fork_id BIGINT;
    __result hive.blocks_range;
    __next_event_block_num INT;
BEGIN
    -- TODO(@Mickiewicz): get context id to do not repeat searching by name
    CASE _context_state.next_event_type
        WHEN 'BACK_FROM_FORK' THEN
            SELECT hf.id, hf.block_num INTO __fork_id, __next_event_block_num
            FROM hive.fork hf
            WHERE hf.id = _context_state.next_event_block_num; -- block_num for BFF events = fork_id

            PERFORM hive.context_back_from_fork( _context, __next_event_block_num );

            UPDATE hive.contexts
            SET
                current_block_num = __next_event_block_num
              , fork_id = __fork_id
            WHERE name = _context;
            RETURN NULL;
        WHEN 'NEW_IRREVERSIBLE' THEN
            -- we may got on context  creation irreversible block based on hive.irreversible_data
            -- unfortunetly some slow app may prevent to removing this event, so wee need to process it
            -- but do not update irreversible
            IF ( _context_state.irreversible_block_num < _context_state.next_event_block_num ) THEN
                PERFORM hive.context_set_irreversible_block( _context, _context_state.next_event_block_num );
            END IF;
            RETURN NULL;
        WHEN 'MASSIVE_SYNC' THEN
            --massive events are squashe at the function begin
            -- we may got on context  creation irreversible block based on hive.irreversible_data
            -- unfortunetly some slow app may prevent to removing this event, so we need to process it
            -- but do not update irreversible
            IF ( _context_state.irreversible_block_num < _context_state.next_event_block_num ) THEN
                PERFORM hive.context_set_irreversible_block( _context, _context_state.next_event_block_num );
            END IF;
        -- no RETURN here because code after the case will continue processing irreversible blocks only
        WHEN 'NEW_BLOCK' THEN
            ASSERT  _context_state.next_event_block_num > _context_state.current_block_num, 'We could not process block without consume event';
            IF _context_state.next_event_block_num = ( _context_state.current_block_num + 1 ) THEN
                UPDATE hive.contexts
                SET current_block_num = _context_state.next_event_block_num
                WHERE name = _context;

                __result.first_block = _context_state.next_event_block_num;
                __result.last_block = _context_state.next_event_block_num;
                RETURN __result ;
            END IF;
            -- it is impossible to have hole between __current_block_num and NEW_BLOCK event block_num
            -- when __current_block_num is not irreversible
            ASSERT _context_state.current_block_num <= _context_state.irreversible_block_num, 'current_block_num is reversible!';
        ELSE
        END CASE;

    -- if there is no event or we still process irreversible blocks
    SELECT hc.irreversible_block INTO _context_state.irreversible_block_num
    FROM hive.contexts hc WHERE hc.name = _context;

    SELECT MIN( hb.num ), MAX( hb.num )
    FROM hive.blocks hb
    WHERE hb.num > _context_state.current_block_num AND hb.num <= _context_state.irreversible_block_num
    INTO __next_block_to_process, __last_block_to_process;

    IF __next_block_to_process IS NULL THEN
        -- There is no new and expected block, needs to wait for a new block
        __result.first_block = -1;
        __result.last_block = -2;
        RETURN __result;
    END IF;

    UPDATE hive.contexts
    SET current_block_num = __next_block_to_process
    WHERE name = _context;

    __result.first_block = __next_block_to_process;
    __result.last_block = __last_block_to_process;
    RETURN __result;
END;
$BODY$
;

-- Returns
-- Null -> ask again without waiting
-- negative range -> no block to process, need to wait for next live block
-- positive range (including 0 size) -> range of blocks to process
CREATE OR REPLACE FUNCTION hive.app_process_event_non_forking( _context hive.context_name, _context_state hive.context_state )
    RETURNS hive.blocks_range
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __next_block_to_process INT;
    __last_block_to_process INT;
    __result hive.blocks_range;
BEGIN
    CASE _context_state.next_event_type
        WHEN 'NEW_IRREVERSIBLE' THEN
            IF _context_state.next_event_block_num > _context_state.irreversible_block_num THEN
                PERFORM hive.context_set_irreversible_block( _context, _context_state.next_event_block_num );
            END IF;
        WHEN 'MASSIVE_SYNC' THEN
            IF _context_state.next_event_block_num > _context_state.irreversible_block_num THEN
                PERFORM hive.context_set_irreversible_block( _context, _context_state.next_event_block_num );
            END IF;
        ELSE
        END CASE;

    SELECT MIN( hb.num ), MAX( hb.num )
    FROM hive.blocks hb
    WHERE hb.num > _context_state.current_block_num AND hb.num <= _context_state.irreversible_block_num
    INTO __next_block_to_process, __last_block_to_process;

    IF __next_block_to_process IS NULL THEN
        -- There is no new and expected block, needs to wait for a new block
        __result.first_block = -1;
        __result.last_block = -2;
        RETURN __result;
    END IF;

    UPDATE hive.contexts
    SET current_block_num = __next_block_to_process
    WHERE name = _context;

    __result.first_block = __next_block_to_process;
    __result.last_block = __last_block_to_process;

    RETURN __result;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_next_block_forking_app( _context_names hive.contexts_group )
    RETURNS hive.blocks_range
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_state hive.context_state;
    __result hive.blocks_range[];
BEGIN
    PERFORM hive.wait_for_ready_instance('178000000 years'::interval);
    SELECT * FROM hive.squash_and_get_state( _context_names ) INTO __context_state;

    SELECT ARRAY_AGG( hive.app_process_event(contexts.*, __context_state) ) INTO __result
    FROM unnest( _context_names ) as contexts;

    IF __result[1].first_block > __result[1].last_block THEN
        PERFORM pg_sleep( 1.5 );
        RETURN NULL;
    END IF;

    RETURN __result[1];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_next_block_non_forking_app( _context_names hive.contexts_group )
    RETURNS hive.blocks_range
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __result hive.blocks_range[];
    __context_state hive.context_state;
BEGIN
    PERFORM hive.wait_for_ready_instance('178000000 years'::interval);
    SELECT * FROM hive.squash_and_get_state( _context_names ) INTO __context_state;
    SELECT ARRAY_AGG( hive.app_process_event_non_forking(contexts.*, __context_state) ) INTO __result
    FROM unnest( _context_names ) as contexts;

    IF __result[1].first_block > __result[1].last_block THEN
        PERFORM pg_sleep( 1.5 );
        RETURN NULL;
    END IF;

    RETURN __result[1];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_one_state_providers( _first_block hive.blocks.num%TYPE, _last_block hive.blocks.num%TYPE, _state_provider HIVE.STATE_PROVIDERS, _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format(
          'SELECT hive.update_state_provider_%s( %s, %s, %L )'
        , _state_provider, _first_block, _last_block, _context
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.refresh_irreversible_block_for_all_contexts( _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    --Increasing `irreversible_block` for every context except contexts that already processed blocks higher than `_new_irreversible_block` value.
    --so as to remove redundant records from `irreversible` tables,
    --because it's no need to hold the same records in both types of tables `reversible`/`irreversible`,
    --(every context retrieves records using a view, that finally returns data from both types of tables using UNION ALL operator).
    UPDATE hive.contexts
    SET irreversible_block = _new_irreversible_block
    WHERE current_block_num <= irreversible_block AND _new_irreversible_block > irreversible_block;
END;
$BODY$
;
