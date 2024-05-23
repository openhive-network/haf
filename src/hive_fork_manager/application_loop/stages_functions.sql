CREATE OR REPLACE FUNCTION hive.validate_stages( _stages hive.application_stages )
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
    WHERE s1.row = hive.live_stage();

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
        ( ( SELECT COALESCE( hid.consistent_block, 0 ) - ctx.current_block_num FROM hive.irreversible_data hid ) ) INTO __lead_context_distance_to_irr_hb
    FROM hive.contexts ctx
    WHERE ctx.name = _contexts [ 1 ];

    RETURN __lead_context_distance_to_irr_hb <= 0;
END;
$BODY$;


CREATE OR REPLACE FUNCTION hive.get_current_stage( _contexts hive.contexts_group )
    RETURNS TABLE( stage hive.application_stage, context hive.context_name )
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __lead_context_distance_to_irr_hb INTEGER;
BEGIN
    --hmm lepiej to posortować w trakcie wsadzania do kontekstu, wtedy
    --nietety trzeba obsugiwac grupe kontextow
    -- funkcja musi zwracac tablice kteks i jego biezacy stage
    --      po to zeby wywolac odpowienie funkcje dla tej aplikacj w danym stagu
    --      max. ilosc blokow zwracana do przetworzenia musi byc najmniejsza iloscia dozwolona dla kotextow z grupy (dla ich stagy)
    -- hmm, taki algorytm oznacza detach wszystkich kotekstow, nawet tych ktore tego nie potrzebuja dla tak malej ilosci blokow
    -- czy to zle ?
    -- 1. poniewaz detach odbywa sie tylko w stanie irreversible (puste shadow tables), ksztal aplikacji nie powinien wplywac na jego predkosc (najdluzej trwa disable triggerow)
    -- 2. przy attachu trzeba szukac eventu, ale tu tez ksztal aplikacji nie ma znaczenia, dla kazdej ta sama zlozonosc
    -- 3. efekt synergi, palikacje ktor mogly by przetwarzac wiecej blokow na raz tegonie zrobi, wiec beda dzialac wolniej co ogolnie
    --    bedzie miao wpyw na predkosc synca caej grupy, ale gdyby najwolniejszy kotekst zostal zmuszony do polkniecia duzej ilosci
    --    blokow moglo by sie okaza ze to on spowolni grupe
    --SELECT s.stage INTO __result
    --FROM ( SELECT ROW(stages.*)::hive.application_stage as stage FROM UNNEST( _stages ) stages ) as s
    --WHERE s.stage.min_head_block_distance <= _distance
    --LIMIT 1;

    PERFORM hive.app_check_contexts_synchronized( _contexts );

    -- if we are traversing reversible blocks
    IF hive.is_abs_livesync( _contexts ) THEN
        RETURN QUERY SELECT
            hive.live_stage() as stage
          , UNNEST( _contexts ) as context
        ;
    END IF;

    SELECT
        ( ( SELECT COALESCE( MAX(hb.num), 0 ) - ctx.current_block_num FROM hive.blocks hb ) ) INTO __lead_context_distance_to_irr_hb
    FROM hive.contexts ctx
    WHERE ctx.name = _contexts [ 1 ];

    RETURN QUERY
    WITH stages AS MATERIALIZED (
        SELECT
              UNNEST( ctx.stages )::hive.application_stage as stage
            , ctx.name as context
            , ctx.current_block_num as current_block_num
        FROM hive.contexts ctx
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