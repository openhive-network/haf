CREATE OR REPLACE FUNCTION hive.get_context_id( _context hive.context_name )
    RETURNS hive.contexts.id%TYPE
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
BEGIN
    SELECT hac.id INTO __context_id
    FROM hive.contexts hac
    WHERE hac.name = _context;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    RETURN __context_id;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_postgres_url()
    RETURNS TEXT
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __current_pid INT;
    __database_name TEXT;
    __postgres_url TEXT;
BEGIN
    __current_pid := pg_backend_pid();
    SELECT datname AS database_name
    FROM pg_stat_activity
    WHERE pid = __current_pid INTO __database_name;

    __postgres_url := 'postgres:///' || __database_name;
    RAISE NOTICE '__postgres_url=%', __postgres_url;
    RETURN __postgres_url;
END;
$BODY$
;

