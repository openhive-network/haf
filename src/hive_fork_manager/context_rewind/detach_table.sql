-- Whe a table is deteted their triggers are removed automatically
-- and there is no need to remove hive_rowid column
CREATE OR REPLACE FUNCTION hive.clean_after_uregister_table( _schema_name TEXT, _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __table_id INTEGER := NULL;
    __shadow_table_name TEXT;
    __trigger_funtion_name TEXT;
BEGIN
    PERFORM hive.dlog('<no-context>', 'Entering clean_after_uregister_table');
    SELECT hrt.id, hrt.shadow_table_name
    FROM hive.registered_tables hrt
    WHERE hrt.origin_table_schema = _schema_name AND  hrt.origin_table_name = _table_name INTO __table_id, __shadow_table_name;

    IF __table_id IS NULL THEN
        RAISE EXCEPTION 'Table is not registered';
    END IF;

    -- remove triggers functions
    FOR  __trigger_funtion_name IN SELECT ht.function_name FROM hive.triggers ht
    WHERE ht.registered_table_id = __table_id
    LOOP
       EXECUTE format( 'DROP FUNCTION %s', __trigger_funtion_name );
    END LOOP;

    -- remove informations about triggers
    DELETE FROM hive.triggers ht WHERE ht.registered_table_id = __table_id;

    --drop shadow table
    EXECUTE format( 'DROP TABLE hive.%I', __shadow_table_name );

    DELETE FROM hive.registered_tables hrt WHERE  hrt.origin_table_schema = _schema_name AND hrt.origin_table_name = _table_name;
    PERFORM hive.dlog('<no-context>', 'Exiting clean_after_uregister_table');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.detach_table( _table_schema TEXT, _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __table_id INTEGER := NULL;
    __shadow_table_name TEXT;
    __trigger_name TEXT;
    __shadow_table_is_not_empty BOOL := FALSE;
BEGIN
    PERFORM hive.dlog('<no-context>', 'Entering detach_table');
    SELECT hrt.id, hrt.shadow_table_name
    FROM hive.registered_tables hrt
    WHERE  hrt.origin_table_schema = lower( _table_schema ) AND hrt.origin_table_name = _table_name INTO __table_id, __shadow_table_name;

    IF __table_id IS NULL THEN
        RAISE EXCEPTION 'Table %.% is not registered', _table_schema, _table_name;
    END IF;

    EXECUTE format( 'SELECT EXISTS( SELECT * FROM hive.%I LIMIT 1 )', __shadow_table_name ) INTO __shadow_table_is_not_empty;

    IF __shadow_table_is_not_empty = TRUE THEN
        RAISE EXCEPTION 'Cannot detach a table %.%. Shadow table hive.% is not empty', _table_schema, _table_name, __shadow_table_name;
    END IF;

    PERFORM hive.drop_triggers( _table_schema, _table_name );
    PERFORM hive.dlog('<no-context>', 'Exiting detach_table');

    RETURN;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.attach_table( _table_schema TEXT, _table_name TEXT, _context_id hive.contexts.id%TYPE )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __table_id INTEGER := NULL;
    __shadow_table_name TEXT;
    __trigger_name TEXT;
BEGIN
    PERFORM hive.dlog('<no-context>', 'Entering attach_table');
    SELECT hrt.id, hrt.shadow_table_name
    FROM hive.registered_tables hrt
    JOIN hive.contexts hc ON hc.id = hrt.context_id
    WHERE
          hrt.origin_table_schema = lower( _table_schema )
      AND hrt.origin_table_name = _table_name
      AND hc.is_attached = FALSE
    INTO __table_id, __shadow_table_name;

    IF __table_id IS NULL THEN
            RAISE EXCEPTION 'Table %.% is not registered or is already attached', _table_schema, _table_name;
    END IF;

    PERFORM hive.create_triggers( _table_schema, _table_name, _context_id );
    PERFORM hive.dlog('<no-context>', 'Exiting attach_table');
END;
$BODY$
;
