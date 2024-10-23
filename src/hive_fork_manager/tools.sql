CREATE OR REPLACE FUNCTION hive.get_context_id( _context hafd.context_name )
    RETURNS hafd.contexts.id%TYPE
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __context_id hafd.contexts.id%TYPE;
BEGIN
    SELECT hac.id INTO __context_id
    FROM hafd.contexts hac
    WHERE hac.name = _context;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    RETURN __context_id;
END;
$BODY$
;
