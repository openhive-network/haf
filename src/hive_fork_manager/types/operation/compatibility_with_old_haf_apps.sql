-- for compatibility with old HAF apps add some aliases for types moved to hive_data schema

CREATE DOMAIN hive.operation AS hive_data.operation;
CREATE DOMAIN hive.application_stages AS hive_data.application_stage[];
CREATE DOMAIN hive.context_name AS hive_data.context_name;
CREATE DOMAIN hive.contexts_group AS hive_data.context_name[] NOT NULL CONSTRAINT non_empty_contexts_group CHECK( CARDINALITY( VALUE ) > 0 );



CREATE FUNCTION hive.live_stage()
    RETURNS hive_data.application_stage
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN hive_data.live_stage();
END;
$BODY$;