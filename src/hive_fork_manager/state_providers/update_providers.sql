CREATE OR REPLACE FUNCTION hive.state_provider_update_runtime( _provider hafd.state_providers, _context hafd.context_name)
    RETURNS void
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    EXECUTE format('SELECT hive.runtimecode_provider_%s(%L)', _provider, _context );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.state_providers_update_runtime( )
    RETURNS void
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM
        hive.state_provider_update_runtime(spr.state_provider, hc.name )
    FROM hafd.state_providers_registered spr
    JOIN hafd.contexts hc ON hc.id = spr.context_id;
END;
$BODY$
;


