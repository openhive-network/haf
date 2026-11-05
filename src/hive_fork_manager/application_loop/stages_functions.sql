CREATE OR REPLACE FUNCTION hive.validate_stages( _stages hafd.application_stages )
RETURNS void
LANGUAGE plpgsql
IMMUTABLE
AS
$BODY$
DECLARE
    __number_of_stages INTEGER = 0;
BEGIN
    SELECT count(*) INTO __number_of_stages
    FROM UNNEST( _stages ) s1
    JOIN UNNEST(_stages ) s2 ON s1.name = s2.name;

    IF __number_of_stages != CARDINALITY( _stages ) THEN
        RAISE EXCEPTION 'Name of stage repeats in stages array %', _stages;
    END IF;

    SELECT count(*) INTO __number_of_stages
    FROM UNNEST( _stages ) s1
    JOIN UNNEST(_stages ) s2 ON s1.min_head_block_distance = s2.min_head_block_distance;

    IF __number_of_stages != CARDINALITY( _stages ) THEN
        RAISE EXCEPTION 'Distance to head block repeats in stages array %', _stages;
    END IF;

    SELECT count(*) INTO __number_of_stages
    FROM ( SELECT ROW(s.*) FROM UNNEST( _stages ) s ) as s1
    WHERE s1.row = hafd.live_stage();

    IF __number_of_stages = 0 THEN
        RAISE EXCEPTION 'No live stage in stages array %', _stages;
    END IF;
END;
$BODY$;

-- abs livesync occur when context is working on reversible blocks
-- is a subset of livesync, which may occur starting form some distance to irreversible head block
CREATE OR REPLACE FUNCTION hive.is_abs_livesync( _contexts hive.contexts_group )
    RETURNS BOOL
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __lead_context_distance_to_irr_hb INTEGER;
BEGIN
    SELECT
        CASE hive.get_sync_state()
        WHEN 'LIVE' THEN
            ( COALESCE( hive.app_get_irreversible_block(), 0 ) - ctx.current_block_num )
        ELSE
            ( COALESCE( hive.get_estimated_hive_head_block(), 0 ) - ctx.current_block_num )
        END INTO __lead_context_distance_to_irr_hb
    FROM hafd.contexts ctx
    WHERE ctx.name = _contexts [ 1 ]
    LIMIT 1;

    RETURN __lead_context_distance_to_irr_hb <= 0;
END;
$BODY$;


CREATE OR REPLACE FUNCTION hive.get_current_stage( _contexts hive.contexts_group )
    RETURNS TABLE( stage hafd.application_stage, context hafd.context_name )
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __lead_context_distance_to_irr_hb INTEGER;
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );

    -- if we are traversing reversible blocks
    IF hive.is_abs_livesync( _contexts ) THEN
        RETURN QUERY SELECT
            hafd.live_stage() as stage
          , UNNEST( _contexts ) as context
        ;
    END IF;

    SELECT
        CASE hive.get_sync_state()
        WHEN 'LIVE' THEN
            ( COALESCE( hive.app_get_irreversible_block(), 0 ) - ctx.current_block_num )
        ELSE
            ( COALESCE( hive.get_estimated_hive_head_block(), 0 ) - ctx.current_block_num )
        END
        INTO __lead_context_distance_to_irr_hb
    FROM hafd.contexts ctx
    WHERE ctx.name = _contexts [ 1 ]
    LIMIT 1;

    RETURN QUERY
    WITH stages AS MATERIALIZED (
        SELECT
              UNNEST ( ctx.stages )::hafd.application_stage as stage
            , ctx.name as context
            , ctx.current_block_num as current_block_num
        FROM hafd.contexts ctx
        WHERE ctx.name = ANY( _contexts )
    ), stages_and_distance AS MATERIALIZED (
        SELECT
               stg.stage as stage
             , (stg.stage).min_head_block_distance - __lead_context_distance_to_irr_hb as distance_to_stage
             , stg.context as context
        FROM stages as stg
    ),  max_distance AS MATERIALIZED (
        SELECT
              sad.context as context
            , MAX(sad.distance_to_stage) as max_distance_to_stage
        FROM stages_and_distance sad
        WHERE sad.distance_to_stage <= 0
        GROUP BY sad.context
    )   SELECT
           sg.stage
         , md.context
        FROM max_distance md
        JOIN stages_and_distance sg ON sg.context = md.context AND sg.distance_to_stage = md.max_distance_to_stage;
END;
$BODY$;


CREATE FUNCTION hive.stage(
      _name hafd.stage_name
    , _min_head_block_distance hafd.blocks_distance
    , _blocks_limit_in_group hafd.blocks_count
    , _processing_alarm_threshold INTERVAL = '5 seconds')
    RETURNS hafd.application_stage
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN (
          _name
        , _min_head_block_distance
        , _blocks_limit_in_group
        , _processing_alarm_threshold
    )::hafd.application_stage;
END;
$BODY$;
CREATE OR REPLACE FUNCTION hive.default_stages()
    RETURNS hafd.application_stages
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN ARRAY[ hive.stage( 'MASSIVE_PROCESSING', 100, 1000 ), hafd.live_stage() ];
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_context_set_stages( _contexts hive.contexts_group, _stages hafd.application_stages )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __updated INTEGER;
BEGIN
    IF _stages IS NULL THEN
        RAISE EXCEPTION 'Stages for contexts % cannot be NULL', _contexts;
    END IF;
    PERFORM hive.validate_stages( _stages );

    UPDATE hafd.contexts
    SET stages = _stages
    WHERE name = ANY( _contexts );
    GET DIAGNOSTICS __updated = ROW_COUNT;

    IF __updated != ( SELECT COUNT( DISTINCT c ) FROM unnest( _contexts ) AS c ) THEN
        RAISE EXCEPTION 'Some contexts from group % do not exist', _contexts;
    END IF;
END;
$BODY$;

-- Sets hive.default_stages() on the contexts of the group that have no stages; other contexts are left unchanged.
CREATE OR REPLACE FUNCTION hive.app_context_set_default_stages( _contexts hive.contexts_group )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context TEXT;
BEGIN
    FOR __context IN
        SELECT hc.name FROM hafd.contexts hc WHERE hc.name = ANY( _contexts ) AND hc.stages IS NULL ORDER BY hc.name
    LOOP
        RAISE NOTICE 'Context % has no stages defined, hive.app_next_iteration sets the default stages %. Declare stages with hive.app_create_context( _stages => ... ) or hive.app_context_set_stages',
            __context, hive.default_stages();
        PERFORM hive.app_context_set_stages( ARRAY[ __context ], hive.default_stages() );
    END LOOP;
END;
$BODY$;
