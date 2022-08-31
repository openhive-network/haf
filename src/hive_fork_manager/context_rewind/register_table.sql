CREATE OR REPLACE FUNCTION hive.create_revert_functions( _table_schema TEXT,  _table_name TEXT, _shadow_table_name TEXT, _columns TEXT[] )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
__columns TEXT = array_to_string( _columns, ',' );
BEGIN
    PERFORM hive.dlog('<no-context>', 'Entering create_revert_functions');
    -- rewind_insert
    EXECUTE format(
        'CREATE OR REPLACE FUNCTION hive.%I_%I_revert_insert( _row_id BIGINT )
        RETURNS void
        LANGUAGE plpgsql
        VOLATILE
        AS
        $$
        BEGIN
            PERFORM hive.dlog(''<no-context>'', ''Entering %I_%I_revert_insert'');
            DELETE FROM %I.%I WHERE hive_rowid = _row_id;
            PERFORM hive.dlog(''<no-context>'', ''Exiting %I_%I_revert_insert'');

        END;
        $$'
    , _table_schema,  _table_name
    , _table_schema,  _table_name
    , _table_schema,  _table_name
    , _table_schema,  _table_name
    );

    --rewind delete
    EXECUTE format(
        'CREATE OR REPLACE FUNCTION hive.%I_%I_revert_delete( _operation_id BIGINT )
        RETURNS void
        LANGUAGE plpgsql
        VOLATILE
        AS
        $$
        BEGIN
            PERFORM hive.dlog(''<no-context>'', ''Entering %I_%I_revert_delete'');
            INSERT INTO %I.%I( %s )
            (
                SELECT %s
                FROM hive.%I st
                WHERE st.hive_operation_id = _operation_id
            );
            PERFORM hive.dlog(''<no-context>'', ''Exiting %I_%I_revert_delete'');

        END;
        $$'
    , _table_schema, _table_name
    , _table_schema, _table_name
    , _table_schema, _table_name, __columns
    , __columns
    , _shadow_table_name
    , _table_schema, _table_name
    );

    EXECUTE format(
        'CREATE OR REPLACE FUNCTION hive.%I_%I_revert_update( _operation_id BIGINT, _row_id BIGINT )
        RETURNS void
        LANGUAGE plpgsql
        VOLATILE
        AS
        $$
        BEGIN
            PERFORM hive.dlog(''<no-context>'', ''Entering %I_%I_revert_update'');
            UPDATE %I.%I as t SET ( %s ) = (
            SELECT %s
            FROM hive.%I st1
            WHERE st1.hive_operation_id = _operation_id
            )
            WHERE t.hive_rowid = _row_id;
            PERFORM hive.dlog(''<no-context>'', ''Exiting %I_%I_revert_update'');

        END;
        $$'
    , _table_schema, _table_name
    , _table_schema, _table_name
    , _table_schema, _table_name, __columns
    , __columns
    , _shadow_table_name
    , _table_schema, _table_name
    );
    PERFORM hive.dlog('<no-context>', 'Exiting create_revert_functions');
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
    PERFORM hive.dlog('<no-context>', 'Entering drop_revert_functions');
    -- rewind_insert
    EXECUTE format(
          'DROP FUNCTION hive.%I_%I_revert_insert'
        , _table_schema,  _table_name
        , _table_schema,  _table_name
    );

    --rewind delete
    EXECUTE format(
          'DROP FUNCTION hive.%I_%I_revert_delete'
        , _table_schema, _table_name
        , _table_schema, _table_name
    );

    EXECUTE format(
          'DROP FUNCTION hive.%I_%I_revert_update'
        , _table_schema, _table_name
        , _table_schema, _table_name
    );
    PERFORM hive.dlog('<no-context>', 'Exiting drop_revert_functions');
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
    PERFORM hive.dlog('<no-context>', 'Entering create_shadow_table');
    EXECUTE format('CREATE TABLE hive.%I AS TABLE %I.%I', __shadow_table_name, _table_schema, _table_name );
    EXECUTE format('DELETE FROM hive.%I', __shadow_table_name ); --empty shadow table if origin table is not empty
    EXECUTE format('ALTER TABLE hive.%I ADD COLUMN %I INTEGER NOT NULL', __shadow_table_name, __block_num_column_name );
    EXECUTE format('ALTER TABLE hive.%I ADD COLUMN %I hive.TRIGGER_OPERATION NOT NULL', __shadow_table_name, __operation_column_name );
    EXECUTE format('ALTER TABLE hive.%I ADD COLUMN %I BIGSERIAL PRIMARY KEY', __shadow_table_name, __operation_id_column_name );
    PERFORM hive.dlog('<no-context>', 'Exiting create_shadow_table');

    RETURN __shadow_table_name;
END;
$BODY$
;


-- creates a shadow table of registered table:
-- | [ table column1, table column2,.... ] | hive_block_num | hive_operation_type |
DROP FUNCTION IF EXISTS hive.register_table;
CREATE FUNCTION hive.register_table( _table_schema TEXT,  _table_name TEXT, _context_name TEXT )
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
    __columns_names TEXT[];
BEGIN
    PERFORM hive.dlog(_context_name, 'Entering register_table');
    PERFORM hive.chceck_constrains(_table_schema, _table_name);

    -- create a shadow table
    SELECT array_agg( iss.column_name::TEXT ) FROM information_schema.columns iss WHERE iss.table_schema=_table_schema AND iss.table_name=_table_name INTO __columns_names;
    SELECT hive.create_shadow_table(  _table_schema, _table_name ) INTO  __shadow_table_name;

    -- insert information about new registered table
    INSERT INTO hive.registered_tables( context_id, origin_table_schema, origin_table_name, shadow_table_name, origin_table_columns, owner )
    SELECT hc.id, tables.table_schema, tables.origin, tables.shadow, columns, current_user
    FROM ( SELECT hc.id FROM hive.contexts hc WHERE hc.name =  _context_name ) as hc
    JOIN ( VALUES( lower(_table_schema), lower(_table_name), __shadow_table_name, __columns_names  )  ) as tables( table_schema, origin, shadow, columns ) ON TRUE
    RETURNING context_id, id INTO __context_id, __registered_table_id
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

    EXECUTE format('CREATE INDEX idx_%I_%I_row_id ON %I.%I(hive_rowid)', lower(_table_schema), lower(_table_name), lower(_table_schema), lower(_table_name) );

    ASSERT __context_id IS NOT NULL, 'There is no context %', _context_name;
    ASSERT __registered_table_id IS NOT NULL;

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
            PERFORM hive.dlog(''<no-context>'', ''Entering %s'');
            SELECT back_from_fork FROM hive.contexts WHERE id=%s INTO __is_back_from_fork_in_progress;

            IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                RETURN NEW;
            END IF;
            SELECT hc.current_block_num FROM hive.contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

            IF ( __block_num <= 0 ) THEN
                 PERFORM hive.elog(''<no-context>'',''Did not execute hive.context_next_block before table edition'');
            END IF;

            INSERT INTO hive.%I SELECT n.*,  __block_num, ''INSERT'' FROM new_table n ON CONFLICT DO NOTHING;
            PERFORM hive.dlog(''<no-context>'', ''Exiting %s'');
            RETURN NEW;
        END;
        $$'
        , __hive_triggerfunction_name_insert
        , __hive_triggerfunction_name_insert
        , __context_id
        , __shadow_table_name
        , __hive_triggerfunction_name_insert
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
            PERFORM hive.dlog(''<no-context>'', ''Entering %s'');
            SELECT back_from_fork FROM hive.contexts WHERE id=%s INTO __is_back_from_fork_in_progress;

            IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                RETURN NEW;
            END IF;

            SELECT hc.current_block_num FROM hive.contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

            IF ( __block_num <= 0 ) THEN
                PERFORM hive.elog(''<no-context>'', ''Did not execute hive.context_next_block before table edition'');
            END IF;

            INSERT INTO hive.%I SELECT o.*, __block_num, ''DELETE'' FROM old_table o ON CONFLICT DO NOTHING;
            PERFORM hive.dlog(''<no-context>'', ''Exiting %s'');
            RETURN NEW;
        END;
        $$'
        , __hive_triggerfunction_name_delete
        , __hive_triggerfunction_name_delete
        , __context_id
        , __shadow_table_name
        , __hive_triggerfunction_name_delete
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
            PERFORM hive.dlog(''<no-context>'', ''Entering %s'');
            SELECT back_from_fork FROM hive.contexts WHERE id=%s INTO __is_back_from_fork_in_progress;

            IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                RETURN NEW;
            END IF;

            SELECT hc.current_block_num FROM hive.contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

            IF ( __block_num <= 0 ) THEN
                PERFORM hive.elog(''<no-context>'', ''Did not execute hive.context_next_block before table edition'');
            END IF;

            INSERT INTO hive.%I SELECT o.*, __block_num, ''UPDATE'' FROM old_table o ON CONFLICT DO NOTHING;
            PERFORM hive.dlog(''<no-context>'', ''Exiting %s'');
            RETURN NEW;
        END;
        $$'
        , __hive_triggerfunction_name_update
        , __hive_triggerfunction_name_update
        , __context_id
        , __shadow_table_name
        , __hive_triggerfunction_name_update
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
             PERFORM hive.dlog(''<no-context>'', ''Entering %s'');
             SELECT back_from_fork FROM hive.contexts WHERE id=%s INTO __is_back_from_fork_in_progress;

             IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                 RETURN NEW;
             END IF;

             SELECT hc.current_block_num FROM hive.contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

             IF ( __block_num <= 0 ) THEN
                 PERFORM hive.elog(''<no-context>'', ''Did not execute hive.context_next_block before table edition'');
             END IF;

             INSERT INTO hive.%I SELECT o.*, __block_num, ''DELETE'' FROM %I.%I o ON CONFLICT DO NOTHING;
             PERFORM hive.dlog(''<no-context>'', ''Exiting %s'');
             RETURN NEW;
         END;
         $$'
        , __hive_triggerfunction_name_truncate
        , __hive_triggerfunction_name_truncate
        , __context_id
        , __shadow_table_name
        , _table_schema
        , _table_name
        , __hive_triggerfunction_name_truncate
    );

    PERFORM hive.create_triggers(  _table_schema, _table_name, __context_id );

    PERFORM hive.create_revert_functions( _table_schema, _table_name, __shadow_table_name, __columns_names );

    -- save information about the triggers
    INSERT INTO hive.triggers( registered_table_id, trigger_name, function_name, owner )
    VALUES
         ( __registered_table_id, __hive_insert_trigger_name, __hive_triggerfunction_name_insert, current_user )
       , ( __registered_table_id, __hive_delete_trigger_name, __hive_triggerfunction_name_delete, current_user )
       , ( __registered_table_id, __hive_update_trigger_name, __hive_triggerfunction_name_update, current_user )
       , ( __registered_table_id, __hive_truncate_trigger_name, __hive_triggerfunction_name_truncate, current_user )
    ;
    PERFORM hive.dlog(_context_name, 'Exiting register_table');
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
    __hive_insert_trigger_name TEXT := hive.get_trigger_insert_name( _table_schema,  _table_name );
    __hive_delete_trigger_name TEXT := hive.get_trigger_delete_name( _table_schema,  _table_name );
    __hive_update_trigger_name TEXT := hive.get_trigger_update_name( _table_schema,  _table_name );
    __hive_truncate_trigger_name TEXT := hive.get_trigger_truncate_name( _table_schema,  _table_name );
    __hive_triggerfunction_name_insert TEXT := hive.get_trigger_insert_function_name( _table_schema,  _table_name );
    __hive_triggerfunction_name_delete TEXT := hive.get_trigger_delete_function_name( _table_schema,  _table_name );
    __hive_triggerfunction_name_update TEXT := hive.get_trigger_update_function_name( _table_schema,  _table_name );
    __hive_triggerfunction_name_truncate TEXT := hive.get_trigger_truncate_function_name( _table_schema,  _table_name );
    __new_sequence_name TEXT := 'seq_' || lower(_table_schema) || '_' || lower(_table_name);
    __context_name TEXT := NULL;
    __registered_table_id INTEGER := NULL;
BEGIN
    PERFORM hive.dlog('<no-context>', 'Entering unregister_table');
    SELECT hc.name, hrt.id INTO __context_name, __registered_table_id
    FROM hive.contexts hc
    JOIN hive.registered_tables hrt ON hrt.context_id = hc.id
    WHERE hrt.origin_table_schema = lower(_table_schema) AND hrt.origin_table_name = lower(_table_name)
    ;

    IF __registered_table_id IS NULL THEN
        RAISE EXCEPTION 'Table %s.%s is not registered', lower(_table_schema), lower(_table_name);
    END IF;

    -- drop shadow table
    EXECUTE format( 'DROP TABLE hive.%s CASCADE', __shadow_table_name );

    -- remove information about triggers
    DELETE FROM hive.triggers WHERE registered_table_id = __registered_table_id;

    -- remove entry about the regitered table
    DELETE FROM hive.registered_tables as hrt  WHERE hrt.origin_table_schema = lower( _table_schema ) AND hrt.origin_table_name = lower( _table_name );

    -- drop functions and triggers
    EXECUTE format( 'DROP FUNCTION %s CASCADE', __hive_triggerfunction_name_insert );
    EXECUTE format( 'DROP FUNCTION %s CASCADE', __hive_triggerfunction_name_delete );
    EXECUTE format( 'DROP FUNCTION %s CASCADE', __hive_triggerfunction_name_update );
    EXECUTE format( 'DROP FUNCTION %s CASCADE', __hive_triggerfunction_name_truncate );

    -- drop revert functions
    PERFORM hive.drop_revert_functions( _table_schema, _table_name );

    -- remove inheritance and sequence
    EXECUTE format( 'ALTER TABLE %I.%s NO INHERIT hive.%s', lower(_table_schema), lower(_table_name), __context_name );
    EXECUTE format( 'ALTER TABLE %I.%s DROP COLUMN hive_rowid CASCADE', lower(_table_schema), lower(_table_name)  );
    PERFORM hive.dlog('<no-context>', 'Exiting unregister_table');
END;
$BODY$
;
