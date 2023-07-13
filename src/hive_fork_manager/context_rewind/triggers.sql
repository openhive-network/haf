CREATE OR REPLACE FUNCTION hive.create_triggers( _table_schema TEXT,  _table_name TEXT, _context_id hive.contexts.id%TYPE )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __shadow_table_name TEXT := hive.get_shadow_table_name( _table_schema, _table_name );
    __hive_insert_trigger_name TEXT := hive.get_trigger_insert_name( _table_schema,  _table_name );
    __hive_delete_trigger_name TEXT := hive.get_trigger_delete_name( _table_schema,  _table_name );
    __hive_update_trigger_name TEXT := hive.get_trigger_update_name( _table_schema,  _table_name );
    __hive_truncate_trigger_name TEXT := hive.get_trigger_truncate_name( _table_schema,  _table_name );
    __hive_triggerfunction_name_insert TEXT := hive.get_trigger_insert_function_name( _table_schema,  _table_name );
    __hive_triggerfunction_name_delete TEXT := hive.get_trigger_delete_function_name( _table_schema,  _table_name );
    __hive_triggerfunction_name_update TEXT := hive.get_trigger_update_function_name( _table_schema,  _table_name );
    __hive_triggerfunction_name_truncate TEXT := hive.get_trigger_truncate_function_name( _table_schema,  _table_name );
    __new_sequence_name TEXT := 'seq_' || lower(_table_schema) || '_' || lower(_table_name);
    __registered_table_id INTEGER := NULL;
    __columns_names TEXT[];
BEGIN
    -- register insert trigger
    EXECUTE format(
            'CREATE TRIGGER %I AFTER INSERT ON %s.%s REFERENCING NEW TABLE AS NEW_TABLE FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
            , __hive_insert_trigger_name
            , _table_schema
            , _table_name
            , __hive_triggerfunction_name_insert
            , _context_id
            , __shadow_table_name
    );

    -- register delete trigger
    EXECUTE format(
            'CREATE TRIGGER %I AFTER DELETE ON %s.%s REFERENCING OLD TABLE AS OLD_TABLE FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
            , __hive_delete_trigger_name
            , _table_schema
            , _table_name
            , __hive_triggerfunction_name_delete
            , _context_id
            , __shadow_table_name
    );

    -- register update trigger
    EXECUTE format(
            'CREATE TRIGGER %I AFTER UPDATE ON %s.%s REFERENCING OLD TABLE AS OLD_TABLE FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
            , __hive_update_trigger_name
            , _table_schema
            , _table_name
            , __hive_triggerfunction_name_update
            , _context_id
            , __shadow_table_name
    );

    -- register truncate trigger
    EXECUTE format(
            'CREATE TRIGGER %I BEFORE TRUNCATE ON %s.%s FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
            , __hive_truncate_trigger_name
            , _table_schema
            , _table_name
            , __hive_triggerfunction_name_truncate
            , _context_id
            , __shadow_table_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_triggers( _table_schema TEXT,  _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __hive_insert_trigger_name TEXT := hive.get_trigger_insert_name( _table_schema,  _table_name );
    __hive_delete_trigger_name TEXT := hive.get_trigger_delete_name( _table_schema,  _table_name );
    __hive_update_trigger_name TEXT := hive.get_trigger_update_name( _table_schema,  _table_name );
    __hive_truncate_trigger_name TEXT := hive.get_trigger_truncate_name( _table_schema,  _table_name );
BEGIN
        -- register insert trigger
    EXECUTE format(
            'DROP TRIGGER %I ON %s.%s'
            , __hive_insert_trigger_name
            , _table_schema
            , _table_name
        );

    -- register delete trigger
    EXECUTE format(
            'DROP TRIGGER %I ON %s.%s'
            , __hive_delete_trigger_name
            , _table_schema
            , _table_name
        );

    -- register update trigger
    EXECUTE format(
            'DROP TRIGGER %I ON %s.%s'
            , __hive_update_trigger_name
            , _table_schema
            , _table_name
        );

    -- register truncate trigger
    EXECUTE format(
            'DROP TRIGGER %I ON %s.%s'
            , __hive_truncate_trigger_name
            , _table_schema
            , _table_name
        );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION contexts_insert_trigger()
    RETURNS trigger
    LANGUAGE plpgsql
AS
$BODY$
    DECLARE
       __number_of_contexts INTEGER;
    BEGIN
        SELECT COUNT( hc.* ) INTO __number_of_contexts FROM hive.contexts hc WHERE hc.owner = current_user;

        IF ( __number_of_contexts > 1000 ) THEN
            RAISE EXCEPTION 'User % cannot create a new context %. The limit of 1000 contexts has been reached.', current_user, NEW.name;
        END IF;

        RETURN NEW;
    END;
$BODY$
;

CREATE OR REPLACE FUNCTION contexts_update_trigger()
    RETURNS trigger
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    IF OLD.is_forking != NEW.is_forking THEN
        RAISE EXCEPTION 'Update hive.contexts.is_forking is forbidden';
    END IF;
    RETURN NEW;
END;
$BODY$
;

DROP TRIGGER IF EXISTS hive_contexts_limit_trigger ON hive.contexts;
CREATE TRIGGER hive_contexts_limit_trigger AFTER INSERT ON hive.contexts FOR EACH ROW EXECUTE FUNCTION contexts_insert_trigger();

DROP TRIGGER IF EXISTS hive_contexts_update_trigger ON hive.contexts;
CREATE TRIGGER hive_contexts_update_trigger BEFORE UPDATE ON hive.contexts FOR EACH ROW EXECUTE FUNCTION contexts_update_trigger();

