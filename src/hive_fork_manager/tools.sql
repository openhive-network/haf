CREATE OR REPLACE FUNCTION hive.get_context_id( _context hive.context_name )
    RETURNS hive.contexts.id%TYPE
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
BEGIN
    PERFORM hive.dlog(_context, '"Entering get_context_id"');
    SELECT hac.id INTO __context_id
    FROM hive.contexts hac
    WHERE hac.name = _context;

    IF __context_id IS NULL THEN
        PERFORM hive.elog(_context, 'No context with name %s', _context::TEXT);
    END IF;
    PERFORM hive.dlog(_context, '"Exiting get_context_id"');

    RETURN __context_id;
END;
$BODY$
;