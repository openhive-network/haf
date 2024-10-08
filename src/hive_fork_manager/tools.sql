CREATE OR REPLACE FUNCTION hive.get_context_id( _context hive_data.context_name )
    RETURNS hive_data.contexts.id%TYPE
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __context_id hive_data.contexts.id%TYPE;
BEGIN
    SELECT hac.id INTO __context_id
    FROM hive_data.contexts hac
    WHERE hac.name = _context;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    RETURN __context_id;
END;
$BODY$
;
