CREATE OR REPLACE FUNCTION hive.get_shadow_table_name( _table_schema TEXT,  _table_name TEXT )
    RETURNS TEXT
    LANGUAGE 'plpgsql'
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN  'shadow_' || lower(_table_schema) || '_' || lower(_table_name);
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_trigger_insert_name( _table_schema TEXT,  _table_name TEXT )
    RETURNS TEXT
    LANGUAGE 'plpgsql'
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN 'hive.hive_insert_trigger_' || lower(_table_schema) || '_' || lower( _table_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_trigger_delete_name( _table_schema TEXT,  _table_name TEXT )
    RETURNS TEXT
    LANGUAGE 'plpgsql'
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN 'hive.hive_delete_trigger_' || lower(_table_schema) || '_' || lower( _table_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_trigger_update_name( _table_schema TEXT,  _table_name TEXT )
    RETURNS TEXT
    LANGUAGE 'plpgsql'
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN 'hive.hive_update_trigger_' || lower(_table_schema) || '_' || lower( _table_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_trigger_truncate_name( _table_schema TEXT,  _table_name TEXT )
    RETURNS TEXT
    LANGUAGE 'plpgsql'
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN 'hive.hive_truncate_trigger_' || lower(_table_schema) || '_' || lower( _table_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_trigger_insert_function_name( _table_schema TEXT,  _table_name TEXT )
    RETURNS TEXT
    LANGUAGE 'plpgsql'
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN 'hive.hive_on_table_trigger_insert_' || lower(_table_schema) || '_' || lower( _table_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_trigger_delete_function_name( _table_schema TEXT,  _table_name TEXT )
    RETURNS TEXT
    LANGUAGE 'plpgsql'
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN 'hive.hive_on_table_trigger_delete_' || lower(_table_schema) || '_' || lower( _table_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_trigger_update_function_name( _table_schema TEXT,  _table_name TEXT )
    RETURNS TEXT
    LANGUAGE 'plpgsql'
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN 'hive.hive_on_table_trigger_update_' || lower(_table_schema) || '_' || lower( _table_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_trigger_truncate_function_name( _table_schema TEXT,  _table_name TEXT )
    RETURNS TEXT
    LANGUAGE 'plpgsql'
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN 'hive.hive_on_table_trigger_truncate_' || lower(_table_schema) || '_' || lower( _table_name );
END;
$BODY$
;
