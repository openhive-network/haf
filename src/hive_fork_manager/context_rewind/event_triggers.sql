CREATE OR REPLACE FUNCTION hive.ignore_registered_table_edition( pg_ddl_command )
    RETURNS BOOLEAN LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'ignore_registered_table_edition';

CREATE OR REPLACE FUNCTION hive.chceck_constrains( _table_schema TEXT,  _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    STABLE
AS
$BODY$
DECLARE
    __exists_non_defferable BOOL := FALSE;
    __constraint_name TEXT;
BEGIN
    EXECUTE format( 'SELECT EXISTS(
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_catalog = current_database()
              AND constraint_type != ''CHECK''
              AND constraint_type != ''PRIMARY KEY''
              AND constraint_type != ''UNIQUE''
              AND constraint_type != ''EXCLUDE''
              AND is_deferrable = ''NO''
              AND table_schema=''%I'' AND table_name=''%I'' )'
    , _table_schema, _table_name )
    INTO __exists_non_defferable;

    IF __exists_non_defferable = TRUE THEN
        RAISE EXCEPTION 'A registered table cannot have non-deferrable referenced constraints. Please check constraints on table %.%'
            , _table_schema, _table_name;
    END IF;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.check_owner( _context hive.context_name, _context_owner TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    STABLE
AS
$BODY$
BEGIN
    IF lower(_context_owner) != lower(CURRENT_USER) THEN
        RAISE EXCEPTION 'User % is not an owner of context % and cannot register tables into it', CURRENT_USER, _context;
    END IF;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.register_state_provider_tables( _context hive.context_name )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    IF EXISTS ( SELECT 1 FROM hive.contexts WHERE name=_context AND registering_state_provider = TRUE )
       OR hive.app_is_forking( _context ) THEN
            RETURN;
    END IF;

    -- register tables
    UPDATE hive.contexts SET registering_state_provider = TRUE WHERE name =  _context;

    PERFORM hive.app_register_table( 'hive', unnest( hsp.tables ), _context )
    FROM hive.state_providers_registered hsp
    JOIN hive.contexts hc ON hc.id = hsp.context_id
    WHERE hc.name = _context;

    UPDATE hive.contexts SET registering_state_provider = FALSE WHERE name =  _context;
END;
$BODY$
;


-- block registerd tables trigger
CREATE OR REPLACE FUNCTION hive.on_edit_registered_tables()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS
$$
DECLARE
__result BOOL := NULL;
__r RECORD;
__shadow_table_name TEXT := NULL;
__origin_table_schema TEXT;
__origin_table_name TEXT;
__new_columns TEXT[];
__ignore_event BOOL;
BEGIN
    SELECT
        hive.ignore_registered_table_edition(command),
        hrt.shadow_table_name,
        hrt.origin_table_schema,
        hrt.origin_table_name,
        hive.check_owner( hc.name, hc.owner )
    FROM
        ( SELECT * FROM pg_event_trigger_ddl_commands() ) as tr
        JOIN hive.registered_tables hrt ON ( hrt.origin_table_schema || '.' || hrt.origin_table_name ) = tr.object_identity
        JOIN hive.contexts hc ON hrt.context_id = hc.id
    INTO __ignore_event, __shadow_table_name, __origin_table_schema, __origin_table_name;

    IF __shadow_table_name IS NULL THEN
        -- maybe ALTER INHERIT ( hive.<context_name> ) to register table into context

        PERFORM
              hive.register_state_provider_tables( tables.context )
            , hive.register_table( tables.schema_name, tables.relname, tables.context )
            , hive.chceck_constrains(tables.schema_name, tables.relname)
        FROM (
            SELECT DISTINCT( pgc.relname ), tr.schema_name, hc.name as context
            FROM pg_event_trigger_ddl_commands() as tr
            JOIN pg_catalog.pg_inherits pgi ON tr.objid = pgi.inhrelid
            JOIN pg_class pgc ON pgc.oid = tr.objid
            JOIN hive.contexts hc ON ( 'hive.' || hc.name )::regclass = pgi.inhparent
            WHERE tr.object_type = 'table'
        ) as tables;
        RETURN;
    END IF;

    IF __ignore_event = TRUE THEN
        RETURN;
    END IF;

    EXECUTE format( 'SELECT EXISTS( SELECT * FROM hive.%I LIMIT 1 )', __shadow_table_name ) INTO __result;

    IF __result = TRUE THEN
        RAISE EXCEPTION 'Cannot edit structure of registered tables when some rows are not rewinded';
    END IF;

    SELECT EXISTS (
        SELECT *
        FROM information_schema.columns iss
        WHERE iss.table_schema = __origin_table_schema
            AND iss.table_name = __origin_table_name
            AND iss.column_name = 'hive_rowid'
    ) INTO __result;

    IF __result = FALSE THEN
        RAISE EXCEPTION 'Cannot remove hive_rowid column';
    END IF;

    -- drop shadow table with old format
    EXECUTE format( 'DROP TABLE hive.%I', __shadow_table_name );
    PERFORM hive.create_shadow_table( __origin_table_schema, __origin_table_name );

    --update information about columns
    SELECT array_agg( iss.column_name::TEXT ) INTO __new_columns
    FROM information_schema.columns iss
    WHERE iss.table_schema = __origin_table_schema AND iss.table_name = __origin_table_name;

    UPDATE hive.registered_tables hrt
    SET origin_table_columns = __new_columns
    WHERE hrt.origin_table_name = lower( __origin_table_name ) AND hrt.origin_table_schema = lower( __origin_table_schema );

    PERFORM hive.chceck_constrains( lower( __origin_table_schema ),  __origin_table_name );
    PERFORM hive.create_revert_functions( lower( __origin_table_schema ),  __origin_table_name, __shadow_table_name, __new_columns );
END;
$$
;

CREATE OR REPLACE FUNCTION hive.on_drop_registered_tables()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS
$$
DECLARE
__r RECORD;
__table TEXT := NULL;
__schema TEXT := NULL;
BEGIN
    SELECT tr.object_name, tr.schema_name  FROM
    ( SELECT * FROM pg_event_trigger_dropped_objects() ) as tr
        JOIN hive.registered_tables hrt ON hrt.origin_table_name  = tr.object_name AND hrt.origin_table_schema = tr.schema_name
    WHERE tr.object_type ='table'
    INTO __table, __schema;

    IF __table IS NOT NULL THEN
        PERFORM hive.clean_after_uregister_table( __schema, __table );
        RAISE WARNING 'Registered table were dropped: %.%', __schema, __table;
    END IF;
END;
$$
;

CREATE OR REPLACE FUNCTION hive.on_create_tables()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS
$$
BEGIN
    PERFORM
          hive.check_owner( tables.context, tables.owner )
        , hive.register_state_provider_tables( tables.context )
        , hive.register_table( tables.schema_name, tables.relname, tables.context )
        , hive.chceck_constrains(tables.schema_name, tables.relname)
    FROM (
        SELECT DISTINCT( pgc.relname ), tr.schema_name, hc.name as context, hc.owner as owner
        FROM pg_event_trigger_ddl_commands() as tr
        JOIN pg_catalog.pg_inherits pgi ON tr.objid = pgi.inhrelid
        JOIN pg_class pgc ON pgc.oid = tr.objid
        JOIN hive.contexts hc ON ( 'hive.' || hc.name )::regclass = pgi.inhparent
        WHERE tr.object_type = 'table'
    ) as tables;
END;
$$
;

DROP EVENT TRIGGER IF EXISTS hive_block_edit_registered_tables_trigger;
CREATE EVENT TRIGGER hive_block_edit_registered_tables_trigger ON ddl_command_end
WHEN TAG IN ( 'ALTER TABLE' )
EXECUTE PROCEDURE hive.on_edit_registered_tables();

DROP EVENT TRIGGER IF EXISTS hive_block_drop_registered_tables_trigger;
CREATE EVENT TRIGGER hive_block_drop_registered_tables_trigger ON sql_drop
WHEN TAG IN ( 'DROP TABLE' )
EXECUTE PROCEDURE hive.on_drop_registered_tables();

DROP EVENT TRIGGER IF EXISTS hive_create_registered_tables_trigger;
CREATE EVENT TRIGGER hive_create_registered_tables_trigger ON ddl_command_end
WHEN TAG IN ( 'CREATE TABLE' )
EXECUTE PROCEDURE hive.on_create_tables();