CREATE FUNCTION hive.log_context( _context_name hafd.context_name, _reason hafd.context_event )
    RETURNS VOID
    LANGUAGE plpgsql
    SECURITY DEFINER
    VOLATILE
AS
$$
DECLARE
    __ctx_current_block INTEGER;
    __ctx_current_fork  BIGINT;
    __ctx_stage hafd.stage_name;

    __head_block INTEGER;
    __head_fork BIGINT;

    __date TIMESTAMP = now();
    __stage_latency INTERVAL;
    __previous_stage TEXT;
BEGIN
    SELECT hc.current_block_num, hc.fork_id
    INTO __ctx_current_block, __ctx_current_fork
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    __ctx_stage = hive.get_current_stage_name( _context_name );

    SELECT COALESCE(MAX(num), 0) -- it must support creating context before any block is added
    INTO __head_block
    FROM hive.blocks_view;

    SELECT MAX(id)
    INTO __head_fork
    FROM hafd.fork;

    INSERT INTO hafd.contexts_log(
                                   context_name
                                 , application_stage
                                 , event_type
                                 , date
                                 , application_block
                                 , application_fork
                                 , head_block
                                 , head_fork_id)
    VALUES (
            _context_name
           , __ctx_stage
           , _reason
           , __date
           , __ctx_current_block
           , __ctx_current_fork
           , __head_block
           , __head_fork
    )
    ;

    IF _reason = 'STATE_CHANGED'::hafd.context_event THEN
        -- there is no need to bother with the query speed
        -- because STATE_CHANGED is relatively rare event
        SELECT
              COALESCE( __date - log.date, '0'::INTERVAL ) as latency
            , application_stage as previous_stage
        INTO
              __stage_latency
            , __previous_stage
        FROM hafd.contexts_log log
        WHERE
            log.context_name =  _context_name
            AND log.event_type = 'STATE_CHANGED'::hafd.context_event
            AND log.application_stage != __ctx_stage
        ORDER BY log.id DESC
        LIMIT 1;

        RAISE WARNING 'PROFILE: CONTEXT ''%'' STAGE_CHANGED FROM ''%'' TO ''%'' AFTER % BLOCK: % FORK: % HIVE BLOCK: % HIVE FORK: %'
            , _context_name
            , COALESCE( __previous_stage::TEXT, 'N/A' )
            , COALESCE( __ctx_stage::TEXT, 'N/A' )
            , COALESCE( __stage_latency::TEXT, 'N/A' )
            , __ctx_current_block
            , __ctx_current_fork
            , __head_block
            , __head_fork
        ;

        RETURN;
    END IF;

    RAISE WARNING 'PROFILE: CONTEXT ''%'' % STAGE: ''%'' BLOCK: % FORK: % HIVE BLOCK: % HIVE FORK: %'
        , _context_name
        , _reason
        , COALESCE(__ctx_stage::TEXT, 'N/A')
        , __ctx_current_block
        , __ctx_current_fork
        , __head_block
        , __head_fork
    ;
END;
$$