CREATE OR REPLACE FUNCTION hive.clean_after_uregister_table( _schema_name TEXT, _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __table_id INTEGER;
BEGIN
    SELECT hrt.id FROM hafd.registered_tables hrt
    WHERE hrt.origin_table_schema = _schema_name AND hrt.origin_table_name = _table_name
    INTO __table_id;

    IF __table_id IS NULL THEN
        RAISE EXCEPTION 'Table is not registered';
    END IF;

    DELETE FROM hafd.triggers ht WHERE ht.registered_table_id = __table_id;
    DELETE FROM hafd.registered_tables hrt WHERE hrt.origin_table_schema = _schema_name AND hrt.origin_table_name = _table_name;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.detach_table( _table_schema TEXT, _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- No-op in irreversible-only mode (no triggers to detach)
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.attach_table( _table_schema TEXT, _table_name TEXT, _context_id hafd.contexts.id%TYPE )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- No-op in irreversible-only mode (no triggers to attach)
END;
$BODY$
;
