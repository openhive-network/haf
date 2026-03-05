CREATE OR REPLACE FUNCTION hive.register_table( _table_schema TEXT,  _table_name TEXT, _context_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __context_id INTEGER := NULL;
    __registered_table_id INTEGER := NULL;
    __columns_names TEXT[];
BEGIN
    PERFORM hive.chceck_constrains(_table_schema, _table_name);

    SELECT array_agg( iss.column_name::TEXT ) FROM information_schema.columns iss WHERE iss.table_schema=_table_schema AND iss.table_name=_table_name INTO __columns_names;

    INSERT INTO hafd.registered_tables as hrt( context_id, origin_table_schema, origin_table_name, shadow_table_name, origin_table_columns, owner )
    SELECT hc.id, tables.table_schema, tables.origin, '', columns, current_user
    FROM ( SELECT hc.id, hive.check_owner( hc.name, hc.owner ) FROM hafd.contexts hc WHERE hc.name = _context_name ) as hc
    JOIN ( VALUES( lower(_table_schema), lower(_table_name), __columns_names  )  ) as tables( table_schema, origin, columns ) ON TRUE
    RETURNING context_id, id
    INTO __context_id, __registered_table_id;

    ASSERT __context_id IS NOT NULL, 'There is no context %', _context_name;
    ASSERT __registered_table_id IS NOT NULL;
END;
$BODY$
;

DROP FUNCTION IF EXISTS hive.unregister_table;
CREATE FUNCTION hive.unregister_table( _table_schema TEXT,  _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __context_name TEXT;
    __context_schema TEXT;
    __registered_table_id INTEGER;
BEGIN
    SELECT hc.name, hrt.id, hc.schema INTO __context_name, __registered_table_id, __context_schema
    FROM hafd.contexts hc
    JOIN hafd.registered_tables hrt ON hrt.context_id = hc.id
    WHERE hrt.origin_table_schema = lower(_table_schema) AND hrt.origin_table_name = lower(_table_name);

    IF __registered_table_id IS NULL THEN
        RAISE EXCEPTION 'Table %s.%s is not registered', lower(_table_schema), lower(_table_name);
    END IF;

    DELETE FROM hafd.triggers WHERE registered_table_id = __registered_table_id;
    DELETE FROM hafd.registered_tables as hrt WHERE hrt.origin_table_schema = lower( _table_schema ) AND hrt.origin_table_name = lower( _table_name );
    EXECUTE format( 'ALTER TABLE IF EXISTS %I.%s NO INHERIT %s.%s', lower(_table_schema), lower(_table_name), __context_schema, __context_name );
END;
$BODY$
;
