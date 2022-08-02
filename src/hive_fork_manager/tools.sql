CREATE OR REPLACE FUNCTION hive.get_context_id( _context hive.context_name )
    RETURNS hive.contexts.id%TYPE
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
BEGIN
    CALL hive.dlogs(_context, 'Entering get_context_id');
    SELECT hac.id INTO __context_id
    FROM hive.contexts hac
    WHERE hac.name = _context;

    IF __context_id IS NULL THEN
        call hive.elogs(_context, format('No context with name %s', _context), TRUE);
    END IF;
    CALL hive.dlogs(_context, 'Exiting get_context_id');

    RETURN __context_id;
END;
$BODY$
;