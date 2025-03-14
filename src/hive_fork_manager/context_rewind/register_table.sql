CREATE OR REPLACE FUNCTION hive.create_revert_functions( _table_schema TEXT,  _table_name TEXT, _shadow_table_name TEXT, _columns TEXT[] )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
__columns TEXT = array_to_string( _columns, ',' );
BEGIN
    -- rewind_insert
    EXECUTE format(
        'CREATE OR REPLACE FUNCTION hafd.%I_%I_revert_insert( _row_id BIGINT )
        RETURNS void
        LANGUAGE plpgsql
        VOLATILE
        AS
        $$
        BEGIN
            DELETE FROM %I.%I WHERE hive_rowid = _row_id;
        END;
        $$'
    , _table_schema,  _table_name
    , _table_schema,  _table_name
    );

    --rewind delete
    EXECUTE format(
        'CREATE OR REPLACE FUNCTION hafd.%I_%I_revert_delete( _operation_id BIGINT )
        RETURNS void
        LANGUAGE plpgsql
        VOLATILE
        AS
        $$
        BEGIN
            INSERT INTO %I.%I( %s )
            (
                SELECT %s
                FROM hafd.%I st
                WHERE st.hive_operation_id = _operation_id
            );
        END;
        $$'
    , _table_schema, _table_name
    , _table_schema, _table_name, __columns
    , __columns
    , _shadow_table_name
    );

    EXECUTE format(
        'CREATE OR REPLACE FUNCTION hafd.%I_%I_revert_update( _operation_id BIGINT, _row_id BIGINT )
        RETURNS void
        LANGUAGE plpgsql
        VOLATILE
        AS
        $$
        BEGIN
            UPDATE %I.%I as t SET ( %s ) = (
            SELECT %s
            FROM hafd.%I st1
            WHERE st1.hive_operation_id = _operation_id
            )
            WHERE t.hive_rowid = _row_id;
        END;
        $$'
    , _table_schema, _table_name
    , _table_schema, _table_name, __columns
    , __columns
    , _shadow_table_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_revert_functions( _table_schema TEXT,  _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- rewind_insert
    EXECUTE format(
          'DROP FUNCTION IF EXISTS hafd.%I_%I_revert_insert'
        , _table_schema,  _table_name
        , _table_schema,  _table_name
    );

    --rewind delete
    EXECUTE format(
          'DROP FUNCTION IF EXISTS hafd.%I_%I_revert_delete'
        , _table_schema, _table_name
        , _table_schema, _table_name
    );

    EXECUTE format(
          'DROP FUNCTION IF EXISTS hafd.%I_%I_revert_update'
        , _table_schema, _table_name
        , _table_schema, _table_name
    );
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.create_shadow_table( _table_schema TEXT,  _table_name TEXT )
    RETURNS TEXT -- name of the shadow table
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __shadow_table_name TEXT := hive.get_shadow_table_name( _table_schema, _table_name );
    __block_num_column_name TEXT := 'hive_block_num';
    __operation_column_name TEXT := 'hive_operation_type';
    __hive_rowid_column_name TEXT := 'hive_rowid';
    __operation_id_column_name TEXT :=  'hive_operation_id';
BEGIN
    EXECUTE format('CREATE TABLE hafd.%I AS TABLE %I.%I', __shadow_table_name, _table_schema, _table_name );
    EXECUTE format('DELETE FROM hafd.%I', __shadow_table_name ); --empty shadow table if origin table is not empty
    EXECUTE format('ALTER TABLE hafd.%I ADD COLUMN %I INTEGER NOT NULL', __shadow_table_name, __block_num_column_name );
    EXECUTE format('ALTER TABLE hafd.%I ADD COLUMN %I hafd.trigger_operation NOT NULL', __shadow_table_name, __operation_column_name );
    EXECUTE format('ALTER TABLE hafd.%I ADD COLUMN %I BIGSERIAL PRIMARY KEY', __shadow_table_name, __operation_id_column_name );

    RETURN __shadow_table_name;
END;
$BODY$
;

DROP FUNCTION IF EXISTS hive.get_rowid_index_name;
CREATE FUNCTION hive.get_rowid_index_name( _table_schema TEXT,  _table_name TEXT )
    RETURNS TEXT
    LANGUAGE 'plpgsql'
    IMMUTABLE
AS
$BODY$
DECLARE
    __index_name TEXT :=  'idx_' || lower(_table_schema) || '_' || lower(_table_name) || '_row_id';
BEGIN
    RETURN __index_name;
END;
$BODY$;

DROP FUNCTION IF EXISTS hive.create_rowid_index;
CREATE FUNCTION hive.create_rowid_index( _table_schema TEXT,  _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format(
          'CREATE INDEX %I ON %I.%I(hive_rowid)'
        , hive.get_rowid_index_name( _table_schema, _table_name )
        , lower(_table_schema), lower(_table_name)
    );
END;
$BODY$;

DROP FUNCTION IF EXISTS hive.drop_rowid_index;
CREATE FUNCTION hive.drop_rowid_index( _table_schema TEXT,  _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format(
          'DROP INDEX %I.%I'
        , lower(_table_schema)
        , hive.get_rowid_index_name( _table_schema, _table_name )
    );
END;
$BODY$;


-- creates a shadow table of registered table:
-- | [ table column1, table column2,.... ] | hive_block_num | hive_operation_type |
CREATE OR REPLACE FUNCTION hive.register_table( _table_schema TEXT,  _table_name TEXT, _context_name TEXT )
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
    __context_id INTEGER := NULL;
    __registered_table_id INTEGER := NULL;
    __attached_context BOOLEAN := FALSE;
    __columns_names TEXT[];
    __is_forking BOOLEAN := TRUE;
BEGIN
    PERFORM hive.chceck_constrains(_table_schema, _table_name);

    -- create a shadow table
    SELECT array_agg( iss.column_name::TEXT ) FROM information_schema.columns iss WHERE iss.table_schema=_table_schema AND iss.table_name=_table_name INTO __columns_names;
    SELECT hive.create_shadow_table(  _table_schema, _table_name ) INTO  __shadow_table_name;

    -- insert information about new registered table
    INSERT INTO hafd.registered_tables as hrt( context_id, origin_table_schema, origin_table_name, shadow_table_name, origin_table_columns, owner )
    SELECT hc.id, tables.table_schema, tables.origin, tables.shadow, columns, current_user
    FROM ( SELECT hc.id, hive.check_owner( hc.name, hc.owner ) FROM hafd.contexts hc WHERE hc.name =  _context_name ) as hc
    JOIN ( VALUES( lower(_table_schema), lower(_table_name), __shadow_table_name, __columns_names  )  ) as tables( table_schema, origin, shadow, columns ) ON TRUE
    RETURNING
          context_id
        , id
        , (SELECT hca.is_attached FROM hafd.contexts hc2 JOIN hafd.contexts_attachment hca ON hca.context_id=hc2.id WHERE hc2.id = hrt.context_id)
        , (SELECT hc2.is_forking FROM hafd.contexts hc2 WHERE hc2.id = hrt.context_id)
        INTO __context_id, __registered_table_id, __attached_context, __is_forking
    ;

    -- create and set separated sequence for hive.base part of the registered table
    EXECUTE format( 'CREATE SEQUENCE %I.%s', lower(_table_schema), __new_sequence_name );
    EXECUTE format( 'ALTER TABLE %I.%I ALTER COLUMN hive_rowid SET DEFAULT nextval( ''%s.%s'' )'
        , lower( _table_schema ), lower( _table_name )
        , lower(_table_schema)
        , __new_sequence_name
        );
    EXECUTE format( 'ALTER SEQUENCE %I.%I OWNED BY %I.%I.hive_rowid'
        , lower(_table_schema)
        , __new_sequence_name
            , lower(_table_schema)
        , lower( _table_name )
        );

    IF __is_forking THEN
        PERFORM hive.create_rowid_index(_table_schema, _table_name );
    END IF;

    ASSERT __context_id IS NOT NULL, 'There is no context %', _context_name;
    ASSERT __registered_table_id IS NOT NULL;

    PERFORM hive.create_revert_functions( _table_schema, _table_name, __shadow_table_name, __columns_names );

    -- create trigger functions
    EXECUTE format(
        'CREATE OR REPLACE FUNCTION %s()
            RETURNS trigger
            LANGUAGE plpgsql
        AS
        $$
        DECLARE
           __block_num INTEGER := NULL;
           __values TEXT;
           __is_back_from_fork_in_progress BOOL := FALSE;
        BEGIN
            SELECT back_from_fork FROM hafd.contexts WHERE id=%s INTO __is_back_from_fork_in_progress;

            IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                RETURN NEW;
            END IF;
            SELECT hc.current_block_num FROM hafd.contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

            IF ( __block_num <= 0 ) THEN
                 RAISE EXCEPTION ''Did not execute hive.context_next_block before table edition'';
            END IF;

            INSERT INTO hafd.%I SELECT n.*,  __block_num, ''INSERT'' FROM new_table n ON CONFLICT DO NOTHING;
            RETURN NEW;
        END;
        $$'
        , __hive_triggerfunction_name_insert
        , __context_id
        , __shadow_table_name
    );

    EXECUTE format(
        'CREATE OR REPLACE FUNCTION %s()
            RETURNS trigger
            LANGUAGE plpgsql
        AS
        $$
        DECLARE
           __block_num INTEGER := NULL;
           __values TEXT;
           __is_back_from_fork_in_progress BOOL := FALSE;
        BEGIN
            SELECT back_from_fork FROM hafd.contexts WHERE id=%s INTO __is_back_from_fork_in_progress;

            IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                RETURN NEW;
            END IF;

            SELECT hc.current_block_num FROM hafd.contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

            IF ( __block_num <= 0 ) THEN
                RAISE EXCEPTION ''Did not execute hive.context_next_block before table edition'';
            END IF;

            INSERT INTO hafd.%I SELECT o.*, __block_num, ''DELETE'' FROM old_table o ON CONFLICT DO NOTHING;
            RETURN NEW;
        END;
        $$'
        , __hive_triggerfunction_name_delete
        , __context_id
        , __shadow_table_name
    );

    EXECUTE format(
        'CREATE OR REPLACE FUNCTION %s()
            RETURNS trigger
            LANGUAGE plpgsql
        AS
        $$
        DECLARE
           __block_num INTEGER := NULL;
           __values TEXT;
           __is_back_from_fork_in_progress BOOL := FALSE;
        BEGIN
            SELECT back_from_fork FROM hafd.contexts WHERE id=%s INTO __is_back_from_fork_in_progress;

            IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                RETURN NEW;
            END IF;

            SELECT hc.current_block_num FROM hafd.contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

            IF ( __block_num <= 0 ) THEN
                RAISE EXCEPTION ''Did not execute hive.context_next_block before table edition'';
            END IF;

            INSERT INTO hafd.%I SELECT o.*, __block_num, ''UPDATE'' FROM old_table o ON CONFLICT DO NOTHING;
            RETURN NEW;
        END;
        $$'
        , __hive_triggerfunction_name_update
        , __context_id
        , __shadow_table_name
    );

    EXECUTE format(
         'CREATE OR REPLACE FUNCTION %s()
             RETURNS trigger
             LANGUAGE plpgsql
         AS
         $$
         DECLARE
            __block_num INTEGER := NULL;
            __values TEXT;
            __is_back_from_fork_in_progress BOOL := FALSE;
         BEGIN
             SELECT back_from_fork FROM hafd.contexts WHERE id=%s INTO __is_back_from_fork_in_progress;

             IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                 RETURN NEW;
             END IF;

             SELECT hc.current_block_num FROM hafd.contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

             IF ( __block_num <= 0 ) THEN
                 RAISE EXCEPTION ''Did not execute hive.context_next_block before table edition'';
             END IF;

             INSERT INTO hafd.%I SELECT o.*, __block_num, ''DELETE'' FROM %I.%I o ON CONFLICT DO NOTHING;
             RETURN NEW;
         END;
         $$'
        , __hive_triggerfunction_name_truncate
        , __context_id
        , __shadow_table_name
        , _table_schema
        , _table_name
    );

    IF __attached_context THEN
      PERFORM hive.create_triggers(  _table_schema, _table_name, __context_id );
    END IF;

    -- save information about the trigger function names
    -- it is required when triggers are removed automatically by postgres when a register table is dropped
    -- in such situation we made cleanup after the deletion in hive.clean_after_uregister_table
    INSERT INTO hafd.triggers( registered_table_id, trigger_name, function_name, owner )
    VALUES
       ( __registered_table_id, __hive_insert_trigger_name, __hive_triggerfunction_name_insert, current_user )
     , ( __registered_table_id, __hive_delete_trigger_name, __hive_triggerfunction_name_delete, current_user )
     , ( __registered_table_id, __hive_update_trigger_name, __hive_triggerfunction_name_update, current_user )
     , ( __registered_table_id, __hive_truncate_trigger_name, __hive_triggerfunction_name_truncate, current_user )
    ;
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
    __shadow_table_name TEXT := hive.get_shadow_table_name( _table_schema, _table_name );
    __hive_triggerfunction_name_insert TEXT := hive.get_trigger_insert_function_name( _table_schema,  _table_name );
    __hive_triggerfunction_name_delete TEXT := hive.get_trigger_delete_function_name( _table_schema,  _table_name );
    __hive_triggerfunction_name_update TEXT := hive.get_trigger_update_function_name( _table_schema,  _table_name );
    __hive_triggerfunction_name_truncate TEXT := hive.get_trigger_truncate_function_name( _table_schema,  _table_name );
    __context_name TEXT := NULL;
    __context_schema TEXT;
    __registered_table_id INTEGER := NULL;
BEGIN
    SELECT hc.name, hrt.id, hc.schema INTO __context_name, __registered_table_id, __context_schema
    FROM hafd.contexts hc
    JOIN hafd.registered_tables hrt ON hrt.context_id = hc.id
    WHERE hrt.origin_table_schema = lower(_table_schema) AND hrt.origin_table_name = lower(_table_name)
    ;

    IF __registered_table_id IS NULL THEN
        RAISE EXCEPTION 'Table %s.%s is not registered', lower(_table_schema), lower(_table_name);
    END IF;

    -- drop shadow table
    EXECUTE format( 'DROP TABLE IF EXISTS hafd.%s CASCADE', __shadow_table_name );

    -- remove information about triggers
    DELETE FROM hafd.triggers WHERE registered_table_id = __registered_table_id;

    -- remove entry about the regitered table
    DELETE FROM hafd.registered_tables as hrt  WHERE hrt.origin_table_schema = lower( _table_schema ) AND hrt.origin_table_name = lower( _table_name );

    -- drop functions and triggers
    EXECUTE format( 'DROP FUNCTION IF EXISTS %s CASCADE', __hive_triggerfunction_name_insert );
    EXECUTE format( 'DROP FUNCTION IF EXISTS %s CASCADE', __hive_triggerfunction_name_delete );
    EXECUTE format( 'DROP FUNCTION IF EXISTS %s CASCADE', __hive_triggerfunction_name_update );
    EXECUTE format( 'DROP FUNCTION IF EXISTS %s CASCADE', __hive_triggerfunction_name_truncate );

    -- drop revert functions
    PERFORM hive.drop_revert_functions( _table_schema, _table_name );

    -- remove inheritance and sequence
    EXECUTE format( 'ALTER TABLE IF EXISTS %I.%s NO INHERIT %s.%s', lower(_table_schema), lower(_table_name), __context_schema, __context_name );
    EXECUTE format( 'ALTER TABLE IF EXISTS %I.%s DROP COLUMN hive_rowid CASCADE', lower(_table_schema), lower(_table_name)  );
END;
$BODY$
;
