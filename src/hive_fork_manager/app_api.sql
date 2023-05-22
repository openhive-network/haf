CREATE OR REPLACE FUNCTION hive.app_create_context( _name hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- Any context always starts with block before genesis, the app may detach the context and execute 'massive sync'
    -- after massive sync the application must attach its context to last already synced block
    PERFORM hive.context_create(
        _name
        , ( SELECT MAX( hf.id ) FROM hive.fork hf ) -- current fork id
        , COALESCE( ( SELECT hid.consistent_block FROM hive.irreversible_data hid ), 0 ) -- head of irreversible block
    );

    PERFORM hive.create_context_data_view( _name );
    PERFORM hive.create_blocks_view( _name );
    PERFORM hive.create_transactions_view( _name );
    PERFORM hive.create_operations_view( _name );
    PERFORM hive.create_signatures_view( _name );
    PERFORM hive.create_accounts_view( _name );
    PERFORM hive.create_account_operations_view( _name );
    PERFORM hive.create_applied_hardforks_view( _name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_remove_context( _name hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_state_provider_drop_all( _name );
    PERFORM hive.context_remove( _name );

    PERFORM hive.drop_applied_hardforks_view( _name );
    PERFORM hive.drop_signatures_view( _name );
    PERFORM hive.drop_operations_view( _name );
    PERFORM hive.drop_transactions_view( _name );
    PERFORM hive.drop_blocks_view( _name );
    PERFORM hive.drop_accounts_view( _name );
    PERFORM hive.drop_account_operations_view( _name );
    PERFORM hive.drop_context_data_view( _name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_reset_data( _name hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
  IF hive.app_context_exists( _name ) THEN
    PERFORM hive.app_remove_context(_name);
  END IF;

  EXECUTE format( 'DROP SCHEMA IF EXISTS %s CASCADE;', _name );
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.app_context_exists( _name TEXT )
    RETURNS BOOL
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN
    RETURN hive.context_exists( _name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_are_forking( _context_names TEXT[] )
    RETURNS BOOL
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result TEXT[];
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _context_names );

    IF array_length( _context_names, 1 ) = 0 THEN
        RAISE  EXCEPTION 'Empty contexts array';
    END IF;

    SELECT ARRAY_AGG( hc.name ) INTO __result
    FROM hive.contexts hc
    WHERE hc.name::TEXT = ANY( _context_names )
    AND EXISTS( SELECT NULL FROM hive.registered_tables hrt WHERE hrt.context_id = hc.id );

    IF array_length( __result, 1 ) IS NULL THEN
        RETURN FALSE;
    END IF;

    IF array_length( __result, 1 ) = 0 THEN
        RETURN FALSE;
    END IF;

    IF array_length( __result, 1 ) != array_length( _context_names, 1 ) THEN
        RAISE EXCEPTION  'Group  %  consists forking and non forking contexts, and only % are forking.', _context_names, __result;
    END IF;

    RETURN TRUE;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_is_forking( _context_name TEXT )
    RETURNS BOOL
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result BOOL;
BEGIN
    -- if there there is a registered table for a given context
    SELECT  * FROM hive.app_are_forking( ARRAY[ _context_name ] ) INTO __result;
    RETURN __result;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_next_block( _context_names TEXT[] )
    RETURNS hive.blocks_range
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _context_names );

    IF EXISTS( SELECT 1 FROM hive.contexts hc WHERE hc.name =ANY( _context_names ) AND hc.is_attached = FALSE ) THEN
        RAISE EXCEPTION 'Detached context cannot be moved';
    END IF;

    -- if there there is  registered table for given context
    IF hive.app_are_forking( _context_names )
    THEN
        RETURN hive.app_next_block_forking_app( _context_names );
    END IF;

    RETURN hive.app_next_block_non_forking_app( _context_names );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_next_block( _context_name TEXT )
    RETURNS hive.blocks_range
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
   RETURN hive.app_next_block( ARRAY[ _context_name ] );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_context_attach( _contexts TEXT[], _last_synced_block INT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __head_of_irreversible_block hive.blocks.num%TYPE:=0;
    __fork_id hive.fork.id%TYPE := 1;
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );

    SELECT hir.consistent_block INTO __head_of_irreversible_block
    FROM hive.irreversible_data hir;

    IF _last_synced_block > __head_of_irreversible_block THEN
        RAISE EXCEPTION 'Cannot attach context % because the block num % is grater than top of irreversible block %'
            , _context, _last_synced_block,  __head_of_irreversible_block;
    END IF;

    SELECT MAX(hf.id) INTO __fork_id FROM hive.fork hf WHERE hf.block_num <= _last_synced_block;

    UPDATE hive.contexts
    SET   fork_id = __fork_id
      , irreversible_block = COALESCE( __head_of_irreversible_block, 0 )
    WHERE name =ANY( _contexts )
    ;

    -- re-create view which mixes irreversible and reversible data
    PERFORM
          hive.context_attach( context.*, _last_synced_block )
        , hive.create_blocks_view(  context.* )
        , hive.create_transactions_view(  context.* )
        , hive.create_operations_view(  context.* )
        , hive.create_signatures_view(  context.* )
        , hive.create_accounts_view(  context.* )
        , hive.create_account_operations_view(  context.* )
        , hive.create_applied_hardforks_view(  context.* )
    FROM unnest( _contexts ) as context;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_context_attach( _context TEXT, _last_synced_block INT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_context_attach( ARRAY[ _context ], _last_synced_block );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_context_detach( _contexts TEXT[] )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );

    PERFORM
          hive.context_detach( context.* )
        , hive.create_all_irreversible_blocks_view( context.* )
        , hive.create_all_irreversible_transactions_view( context.* )
        , hive.create_all_irreversible_operations_view( context.* )
        , hive.create_all_irreversible_signatures_view( context.* )
        , hive.create_all_irreversible_accounts_view( context.* )
        , hive.create_all_irreversible_account_operations_view( context.* )
        , hive.create_all_irreversible_applied_hardforks_view( context.* )
    FROM unnest( _contexts ) as context;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_context_detach( _context TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_context_detach( ARRAY[ _context ] );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_register_table( _table_schema TEXT,  _table_name TEXT,  _context TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format( 'ALTER TABLE %I.%s ADD COLUMN hive_rowid BIGINT NOT NULL DEFAULT 0', _table_schema, _table_name );
    EXECUTE format( 'ALTER TABLE %I.%s INHERIT hive.%s', _table_schema, _table_name, _context );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_unregister_table( _table_schema TEXT,  _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.unregister_table( _table_schema, _table_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_get_irreversible_block( _context_name TEXT DEFAULT '' )
    RETURNS hive.contexts.irreversible_block%TYPE
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result hive.contexts.irreversible_block%TYPE;
BEGIN
    IF  _context_name = '' THEN
        SELECT COALESCE( consistent_block, 0 ) INTO __result FROM hive.irreversible_data;
        RETURN __result;
    END IF;

    IF hive.app_is_forking( _context_name )
    THEN
        SELECT hc.irreversible_block INTO __result
        FROM hive.contexts hc
        WHERE hc.name = _context_name;
    ELSE
        __result := COALESCE((SELECT hb.num from hive.blocks hb ORDER BY num DESC LIMIT 1), 0);
    END IF;

    RETURN __result;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_context_are_attached( _contexts TEXT[] )
    RETURNS bool
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result bool[];
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );

    SELECT ARRAY_AGG( DISTINCT(hc.is_attached) )  is_attached INTO __result
    FROM hive.contexts hc
    WHERE hc.name =ANY( _contexts );

    IF __result IS NULL OR ARRAY_LENGTH( __result, 1 ) != 1 THEN
        RAISE EXCEPTION 'No contexts or attached and detached contexts are present in the same group %', _contexts;
    END IF;

    RETURN __result[ 1 ];
END;
$BODY$;


CREATE OR REPLACE FUNCTION hive.app_context_is_attached( _context TEXT )
    RETURNS bool
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN
    RETURN hive.app_context_are_attached( ARRAY[ _context ] );
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_context_detached_save_block_num( _contexts TEXT[], _block_num INTEGER )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __contexts_id INTEGER[];
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );

    SELECT ARRAY_AGG(hc.id) INTO __contexts_id
    FROM hive.contexts hc
    WHERE hc.name =ANY( _contexts ) AND hc.is_attached = FALSE;

    IF __contexts_id IS NULL OR ARRAY_LENGTH( __contexts_id, 1 ) != ARRAY_LENGTH( _contexts, 1 ) THEN
        RAISE EXCEPTION 'Contexts do not exist or are attached';
    END IF;

    UPDATE hive.contexts hc
    SET detached_block_num = _block_num
    WHERE hc.id =ANY( __contexts_id );
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_context_detached_save_block_num( _context TEXT, _block_num INTEGER )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_context_detached_save_block_num( ARRAY[ _context ], _block_num );
END;
$BODY$;


CREATE OR REPLACE FUNCTION hive.app_context_detached_get_block_num( _contexts TEXT[] )
    RETURNS INTEGER
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result INTEGER[];
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );

    SELECT ARRAY_AGG( hc.detached_block_num ) detached_block_num INTO __result
    FROM hive.contexts hc
    WHERE hc.name =ANY( _contexts ) AND hc.is_attached = FALSE;

    IF __result IS NULL OR ARRAY_LENGTH( __result, 1 ) != ARRAY_LENGTH( _contexts, 1 ) THEN
        RAISE EXCEPTION 'Contexts do not exist or are attached';
    END IF;

    SELECT ARRAY_AGG( DISTINCT( blocks.* ) ) INTO __result
    FROM UNNEST( __result ) as blocks;

    IF ARRAY_LENGTH( __result, 1 ) != 1 THEN
        RAISE EXCEPTION 'Inconsistent block num in context group';
    END IF;

    RETURN __result[ 1 ];
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_context_detached_get_block_num( _context_name TEXT )
    RETURNS INTEGER
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN
    RETURN hive.app_context_detached_get_block_num( ARRAY[ _context_name ] );
END;
$BODY$;


CREATE OR REPLACE FUNCTION hive.app_state_provider_import( _state_provider hive.state_providers, _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
BEGIN

    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
    INTO __context_id;

    __context_id = hive.get_context_id( _context );

    IF EXISTS( SELECT 1 FROM hive.state_providers_registered WHERE context_id = __context_id AND state_provider = _state_provider ) THEN
        RAISE LOG 'The state % provider is already imported for context %.', _state_provider, _context;
        RETURN;
    END IF;


    EXECUTE format(
        'INSERT INTO hive.state_providers_registered( context_id, state_provider, tables, owner )
        SELECT %s , %L, hive.start_provider_%s( %L ), current_user
        ON CONFLICT DO NOTHING', __context_id, _state_provider, _state_provider, _context
    );

    IF NOT hive.app_is_forking( _context ) THEN
        RETURN;
    END IF;

    -- register tables
    PERFORM hive.app_register_table( 'hive', unnest( hsp.tables ), _context )
    FROM hive.state_providers_registered hsp
    WHERE hsp.context_id = __context_id AND hsp.state_provider = _state_provider;
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.app_state_providers_update( _first_block hive.blocks.num%TYPE, _last_block hive.blocks.num%TYPE, _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __is_attached BOOL;
    __current_block_num hive.blocks.num%TYPE;
BEGIN
    SELECT hac.id, hac.is_attached, hac.current_block_num
    FROM hive.contexts hac
    WHERE hac.name = _context
        INTO __context_id, __is_attached, __current_block_num;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    IF __is_attached = TRUE AND _first_block != _last_block  THEN
        RAISE EXCEPTION 'Only one block can be processed when context is attached';
    END IF;

    IF _first_block > _last_block THEN
        RAISE EXCEPTION 'First block % is greater than %', _first_block, _last_block;
    END IF;

    IF  _first_block < __current_block_num THEN
        RAISE EXCEPTION 'First block % is lower than context % current block %', _first_block, _context, __current_block_num;
    END IF;

    PERFORM hive.update_one_state_providers( _first_block, _last_block, hsp.state_provider, _context )
    FROM hive.state_providers_registered hsp
    WHERE hsp.context_id = __context_id;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_state_provider_drop( _state_provider HIVE.STATE_PROVIDERS, _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format(
            'SELECT hive.drop_state_provider_%s( %L )'
        , _state_provider, _context
        );

    DELETE FROM hive.state_providers_registered hsp
        USING hive.contexts hc
    WHERE hc.name = _context AND hsp.state_provider = _state_provider AND hc.id = hsp.context_id;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_state_provider_drop_all( _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_state_provider_drop( hsp.state_provider, _context )
    FROM hive.state_providers_registered hsp
    JOIN hive.contexts hc ON hc.id = hsp.context_id
    WHERE hc.name = _context;
END;
$BODY$
;

DROP FUNCTION IF EXISTS hive.is_instance_ready();

--- Returns true if HAF database is immediately ready for app data processing.
CREATE FUNCTION hive.is_instance_ready()
RETURNS BOOLEAN
AS
$BODY$
BEGIN
  --- Instance is ready when has built all indexes/constraints. We can consider adding here another features if needed
  RETURN NOT EXISTS(SELECT NULL FROM hive.indexes_constraints); 
END
$BODY$
LANGUAGE plpgsql STABLE; 

DROP FUNCTION IF EXISTS hive.wait_for_ready_instance(IN _timeout INTERVAL);
--- Allows to wait (until specified _timeout) until HAF database will be ready for application data processing.
--- Raises exception on _timeout.
CREATE FUNCTION hive.wait_for_ready_instance(IN _timeout INTERVAL DEFAULT '5 min'::INTERVAL)
RETURNS VOID
AS
$BODY$
DECLARE
  __wait_time INTERVAL := '500 ms'::interval;
  __retry INT := 0;
BEGIN
  WHILE (CLOCK_TIMESTAMP() - TRANSACTION_TIMESTAMP() <= _timeout) LOOP
    __retry := __retry + 1;
    IF hive.is_instance_ready() THEN
      RAISE NOTICE 'HAF instance is ready. Existing...';
      RETURN;
    END IF;
    RAISE NOTICE '# %, waiting time: % s - waiting for another % s', __retry, extract(epoch from (CLOCK_TIMESTAMP() - TRANSACTION_TIMESTAMP())), extract(epoch from (__wait_time));

    PERFORM pg_sleep_for(__wait_time);
  END LOOP;
  
  RAISE EXCEPTION 'HAF instance was not resumed in % s', extract(epoch from (_timeout));
END
$BODY$
LANGUAGE plpgsql VOLATILE;


CREATE OR REPLACE FUNCTION hive.app_check_contexts_synchronized( _contexts TEXT[] )
    RETURNS VOID
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __number_of_rows INTEGER;
BEGIN
    SELECT COUNT(
        DISTINCT(
                   ctx.current_block_num
                 , ctx.irreversible_block
                 , ctx.is_attached
                 , ctx.back_from_fork
                 , ctx.events_id
                 , ctx.fork_id
                 , ctx.detached_block_num
        )
    ) INTO __number_of_rows
    FROM hive.contexts ctx
    WHERE ctx.name =ANY(_contexts);

    IF __number_of_rows != 1 THEN
        RAISE EXCEPTION 'Contexts % are not synchronized', _contexts;
    END IF;
END;
$BODY$;
