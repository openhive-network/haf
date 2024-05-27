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


CREATE OR REPLACE FUNCTION hive.get_current_stage( _contexts hive.context_group )
    RETURNS hive.application_stage
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
DECLARE
    __result hive.application_stage;
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
    SELECT s.stage INTO __result
    FROM ( SELECT ROW(stages.*)::hive.application_stage as stage FROM UNNEST( _stages ) stages ) as s
    WHERE s.stage.min_head_block_distance <= _distance
    LIMIT 1;

    WITH stages_and_distance AS MATERIALIZED (
        SELECT
              ROW( UNNEST( ctx.stages ) )::hive.application_stage as stage
             , stage.min_head_block_distance - ( ( SELECT COALESCE( MAX(hb.block_num), 0 ) FROM hive.blocks_view hb )  - ctx.current_block_num ) as distance
             , ctx.name as context
        FROM hive.contexts ctx
        WHERE ctx.name = ANY( _contexts )
    ) SELECT
          MAX( stages_and_distance.distance )
        , stages_and_distance.stage



    ASSERT __result IS NOT NULL, 'No stage chosen for context %', _context;

    RETURN __result;
END;
$BODY$;