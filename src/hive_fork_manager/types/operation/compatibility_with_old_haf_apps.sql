-- for compatibility with old HAF apps add some aliases for types moved to hafd schema

CREATE DOMAIN hive.operation AS hafd.operation;
CREATE DOMAIN hive.application_stages AS hafd.application_stage[];
CREATE DOMAIN hive.context_name AS hafd.context_name;
CREATE DOMAIN hive.contexts_group AS hafd.context_name[] NOT NULL CONSTRAINT non_empty_contexts_group CHECK( CARDINALITY( VALUE ) > 0 );



CREATE FUNCTION hive.live_stage()
    RETURNS hafd.application_stage
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN hafd.live_stage();
END;
$BODY$;