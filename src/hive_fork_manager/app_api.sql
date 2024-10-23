CREATE OR REPLACE FUNCTION hive.app_create_views_for_contexts( _name hive_data.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.create_context_data_view( _name );
    PERFORM hive.create_blocks_view( _name );
    PERFORM hive.create_transactions_view( _name );
    PERFORM hive.create_operations_view( _name );
    PERFORM hive.create_operations_view_extended( _name );
    PERFORM hive.create_signatures_view( _name );
    PERFORM hive.create_accounts_view( _name );
    PERFORM hive.create_account_operations_view( _name );
    PERFORM hive.create_applied_hardforks_view( _name );
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.app_create_context(
      _name hive_data.context_name
    , _schema TEXT
    , _is_forking BOOLEAN = TRUE
    , _is_attached BOOLEAN = TRUE
)
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
        , _schema
        , ( SELECT MAX( hf.id ) FROM hive_data.fork hf ) -- current fork id
        , COALESCE( ( SELECT hid.consistent_block FROM hive_data.irreversible_data hid ), 0 ) -- head of irreversible block
        , _is_forking
        , _is_attached
        , NULL
    );

    PERFORM hive.app_create_views_for_contexts( _name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_create_context(
      _name hive_data.context_name
    , _schema TEXT
    , _stages hive_data.application_stages
    , _is_forking BOOLEAN = TRUE
)
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
        , _schema
        , ( SELECT MAX( hf.id ) FROM hive_data.fork hf ) -- current fork id
        , COALESCE( ( SELECT hid.consistent_block FROM hive_data.irreversible_data hid ), 0 ) -- head of irreversible block
        , _is_forking
        , False
        , _stages
    );

    PERFORM hive.app_create_views_for_contexts( _name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_remove_context( _name hive_data.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_state_provider_drop_all( _name );

    PERFORM hive.drop_applied_hardforks_view( _name );
    PERFORM hive.drop_signatures_view( _name );
    PERFORM hive.drop_operations_view( _name );
    PERFORM hive.drop_operations_view_extended( _name );
    PERFORM hive.drop_transactions_view( _name );
    PERFORM hive.drop_blocks_view( _name );
    PERFORM hive.drop_accounts_view( _name );
    PERFORM hive.drop_account_operations_view( _name );
    PERFORM hive.drop_context_data_view( _name );

    PERFORM hive.context_remove( _name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_reset_data( _name hive_data.context_name )
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

CREATE OR REPLACE FUNCTION hive.app_are_forking( _context_names hive.contexts_group )
    RETURNS BOOL
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result TEXT[];
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _context_names );

    SELECT ARRAY_AGG( hc.name ) INTO __result
    FROM hive_data.contexts hc
    WHERE hc.name::TEXT = ANY( _context_names ) AND hc.is_forking = TRUE;

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

CREATE OR REPLACE FUNCTION hive.app_is_forking( _context_name hive_data.context_name )
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

CREATE OR REPLACE FUNCTION hive.app_next_block( _context_names hive.contexts_group )
    RETURNS hive.blocks_range
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _context_names );

    -- prevent auto-detaching the context when app is actively asking for new blocks
    UPDATE hive_data.contexts
    SET last_active_at = NOW()
    WHERE name =ANY(_context_names);

    -- if there there is  registered table for given context
    IF hive.app_are_forking( _context_names )
    THEN
        RETURN hive.app_next_block_forking_app( _context_names );
    END IF;

    RETURN hive.app_next_block_non_forking_app( _context_names );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_next_block( _context_name hive_data.context_name )
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

CREATE OR REPLACE FUNCTION hive.app_context_attach( _contexts hive.contexts_group )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __head_of_irreversible_block hive_data.blocks.num%TYPE:=0;
    __current_block_num INT;
    __fork_id hive_data.fork.id%TYPE := 1;
    __lead_context hive_data.context_name := _contexts[1];
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );

    -- lock EXCLUSIVE may be taken by hived in function:
    -- hive.set_irreversible
    -- so here we can stuck while hived is servicing a new irreversible block notification
    LOCK TABLE hive_data.contexts_attachment IN ROW SHARE MODE;

    SELECT hc.current_block_num INTO __current_block_num
    FROM hive_data.contexts hc
    WHERE hc.name = __lead_context;

    SELECT hir.consistent_block INTO __head_of_irreversible_block
    FROM hive_data.irreversible_data hir;

    IF __current_block_num > __head_of_irreversible_block THEN
        RAISE EXCEPTION 'Cannot attach context % because the block num % is grater than top of irreversible block %'
            , _context, __current_block_num,  __head_of_irreversible_block;
    END IF;

    SELECT MAX(hf.id) INTO __fork_id FROM hive_data.fork hf WHERE hf.block_num <= GREATEST(__current_block_num, 1);

    UPDATE hive_data.contexts
    SET   fork_id = __fork_id
      , irreversible_block = COALESCE( __head_of_irreversible_block, 0 )
      , events_id = 0 -- during app_next_block correct event will be found
      , last_active_at = NOW()
    WHERE name =ANY( _contexts )
    ;

    -- re-create view which mixes irreversible and reversible data
    PERFORM
          hive.context_attach( context.*, __current_block_num )
        , hive.create_blocks_view(  context.* )
        , hive.create_transactions_view(  context.* )
        , hive.create_operations_view(  context.* )
        , hive.create_operations_view_extended(  context.* )
        , hive.create_signatures_view(  context.* )
        , hive.create_accounts_view(  context.* )
        , hive.create_account_operations_view(  context.* )
        , hive.create_applied_hardforks_view(  context.* )
    FROM unnest( _contexts ) as context;

    RAISE WARNING 'Contexts were % attached on %', _contexts, NOW();
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_context_attach( _context hive_data.context_name )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_context_attach( ARRAY[ _context ] );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE hive.appproc_context_attach( _contexts hive.contexts_group )
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_context_attach( _contexts );
    COMMIT;
END;
$BODY$
;


CREATE OR REPLACE PROCEDURE hive.appproc_context_attach( IN _context hive_data.context_name )
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CALL hive.appproc_context_attach( ARRAY[ _context ] );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_context_detach( _contexts hive.contexts_group )
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
        , hive.create_all_irreversible_operations_view_extended( context.* )
        , hive.create_all_irreversible_signatures_view( context.* )
        , hive.create_all_irreversible_accounts_view( context.* )
        , hive.create_all_irreversible_account_operations_view( context.* )
        , hive.create_all_irreversible_applied_hardforks_view( context.* )
    FROM unnest( _contexts ) as context;

    RAISE WARNING 'Contexts were % detached on %', _contexts, NOW();
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_context_detach(  _context hive_data.context_name )
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

CREATE OR REPLACE FUNCTION hive.app_context_set_non_forking( _contexts hive.contexts_group  )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );

    -- detaching is the best method to remove reversible data and triggers
    PERFORM
          hive.context_detach( context.* )
    FROM unnest( _contexts ) as context;

    UPDATE hive_data.contexts hc
    SET is_forking = false
      , last_active_at = NOW()
    WHERE hc.name = ANY( _contexts );

    -- we are reattaching the contexts but the triggers won't be recreated
    -- because now the contexts are non-forking
    PERFORM
        hive.context_attach( context.text, hc.irreversible_block )
    FROM hive_data.contexts hc
    JOIN unnest( _contexts ) as context ON context.text = hc.name;

    PERFORM hive.drop_rowid_index( hrt.origin_table_schema, hrt.origin_table_name )
    FROM hive_data.registered_tables hrt
    JOIN hive_data.contexts hc ON hrt.context_id = hc.id
    JOIN unnest( _contexts ) as context ON context.text = hc.name;
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.app_context_set_non_forking( _context hive_data.context_name )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_context_set_non_forking( ARRAY[ _context ] );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_context_set_forking( _contexts hive.contexts_group  )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );

    -- detaching is the best method to remove reversible data and triggers
    PERFORM
        hive.context_detach( context.* )
    FROM unnest( _contexts ) as context;

    UPDATE hive_data.contexts hc
    SET is_forking = true
      , last_active_at = NOW()
    WHERE hc.name = ANY( _contexts );
    --recursive
    -- to recreate triggers
    PERFORM
        hive.context_attach( context.text, hc.irreversible_block )
    FROM hive_data.contexts hc
    JOIN unnest( _contexts ) as context ON context.text = hc.name;

    PERFORM hive.create_rowid_index( hrt.origin_table_schema, hrt.origin_table_name )
    FROM hive_data.registered_tables hrt
    JOIN hive_data.contexts hc ON hrt.context_id = hc.id
    JOIN unnest( _contexts ) as context ON context.text = hc.name;

END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.app_context_set_forking( _context hive_data.context_name )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_context_set_forking( ARRAY[ _context ] );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_register_table( _table_schema TEXT,  _table_name TEXT,  _context TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __schema VARCHAR;
BEGIN
    SELECT schema INTO __schema
    FROM hive_data.contexts hc
    WHERE hc.name = _context;
    EXECUTE format( 'ALTER TABLE %I.%s ADD COLUMN hive_rowid BIGINT NOT NULL DEFAULT 0', _table_schema, _table_name );
    EXECUTE format( 'ALTER TABLE %I.%s INHERIT %I.%s', _table_schema, _table_name, __schema, _context );
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

CREATE OR REPLACE FUNCTION hive.app_get_irreversible_block()
    RETURNS hive_data.contexts.irreversible_block%TYPE
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result hive_data.contexts.irreversible_block%TYPE;
BEGIN
    SELECT COALESCE( consistent_block, 0 ) INTO __result FROM hive_data.irreversible_data;
    RETURN __result;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_get_irreversible_block( _context_name hive_data.context_name )
    RETURNS hive_data.contexts.irreversible_block%TYPE
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result hive_data.contexts.irreversible_block%TYPE;
BEGIN
    IF hive.app_is_forking( _context_name )
    THEN
        SELECT hc.irreversible_block INTO __result
        FROM hive_data.contexts hc
        WHERE hc.name = _context_name;
    ELSE
        __result := COALESCE((SELECT hb.num from hive_data.blocks hb ORDER BY num DESC LIMIT 1), 0);
    END IF;

    RETURN __result;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_context_are_attached( _contexts hive.contexts_group )
    RETURNS bool
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result bool[];
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );

    SELECT ARRAY_AGG( DISTINCT(hca.is_attached) )  is_attached INTO __result
    FROM hive_data.contexts_attachment hca
    JOIN hive_data.contexts hc ON hc.id = hca.context_id
    WHERE hc.name =ANY( _contexts );

    IF __result IS NULL OR ARRAY_LENGTH( __result, 1 ) != 1 THEN
        RAISE EXCEPTION 'No contexts or attached and detached contexts are present in the same group %', _contexts;
    END IF;

    RETURN __result[ 1 ];
END;
$BODY$;


CREATE OR REPLACE FUNCTION hive.app_context_is_attached( _context hive_data.context_name )
    RETURNS bool
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN
    RETURN hive.app_context_are_attached( ARRAY[ _context ] );
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_update_last_active_at( _contexts hive.contexts_group )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __contexts_id INTEGER[];
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );

    SELECT ARRAY_AGG(id) INTO __contexts_id
    FROM hive_data.contexts
    WHERE name = ANY( _contexts );

    IF __contexts_id IS NULL THEN
        RAISE EXCEPTION 'Contexts do not exist';
    END IF;

    UPDATE hive_data.contexts SET last_active_at = NOW()
    WHERE id =ANY( __contexts_id );
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_update_last_active_at( _context hive_data.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_update_last_active_at( ARRAY[ _context ]);
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_set_current_block_num( _contexts hive.contexts_group, _block_num INTEGER )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __contexts_id INTEGER[];
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );

    SELECT ARRAY_AGG(id) INTO __contexts_id
    FROM hive_data.contexts hc
    JOIN hive_data.contexts_attachment hca ON hca.context_id = hc.id
    WHERE name = ANY( _contexts ) AND hca.is_attached = FALSE;

    IF __contexts_id IS NULL THEN
        RAISE EXCEPTION 'Contexts do not exist';
    END IF;
    IF ARRAY_LENGTH( __contexts_id, 1 ) != ARRAY_LENGTH( _contexts, 1 ) THEN
        RAISE EXCEPTION 'Cannot directly set current_block_num when contexts are attached';
    END IF;

    UPDATE hive_data.contexts SET current_block_num = _block_num, last_active_at = NOW()
    WHERE id =ANY( __contexts_id );
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_set_current_block_num( _context hive_data.context_name, _block_num INTEGER )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_set_current_block_num( ARRAY[ _context ], _block_num );
END;
$BODY$;


CREATE OR REPLACE FUNCTION hive.app_get_current_block_num( _contexts hive.contexts_group )
    RETURNS INTEGER
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result INTEGER[];
BEGIN
    PERFORM hive.app_check_contexts_synchronized( _contexts );

    SELECT ARRAY_AGG( current_block_num ) current_block_num INTO __result
    FROM hive_data.contexts
    WHERE name =ANY( _contexts );

    IF __result IS NULL THEN
        RAISE EXCEPTION 'Contexts do not exist';
    END IF;

    SELECT ARRAY_AGG( DISTINCT( blocks.* ) ) INTO __result
    FROM UNNEST( __result ) as blocks;

    IF ARRAY_LENGTH( __result, 1 ) != 1 THEN
        RAISE EXCEPTION 'Inconsistent block num in context group %', _contexts;
    END IF;

    RETURN __result[ 1 ];
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_get_current_block_num( _context_name hive_data.context_name )
    RETURNS INTEGER
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN
    RETURN hive.app_get_current_block_num( ARRAY[ _context_name ] );
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.grant_select_for_state_providers_table( _table_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- TODO(mickiewicz@syncad.com) Here is a problem with schema hive_data
    -- not returned by the any of already implemented state_providers
    -- need to investigate why schema is not a part of table name
    -- in the template there is a note that hive. must be returned for each state provider table name
    EXECUTE format( 'GRANT SELECT ON TABLE hive_data.%s TO hive_applications_group', _table_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_state_provider_import( _state_provider hive_data.state_providers, _context hive_data.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive_data.contexts.id%TYPE;
BEGIN

    SELECT hac.id, hive.check_owner( hac.name, hac.owner )
    FROM hive_data.contexts hac
    WHERE hac.name = _context
    INTO __context_id;

    __context_id = hive.get_context_id( _context );

    IF EXISTS( SELECT 1 FROM hive_data.state_providers_registered WHERE context_id = __context_id AND state_provider = _state_provider ) THEN
        RAISE LOG 'The state % provider is already imported for context %.', _state_provider, _context;
        RETURN;
    END IF;


    EXECUTE format(
        'INSERT INTO hive_data.state_providers_registered( context_id, state_provider, tables, owner )
        SELECT %s , %L, hive.start_provider_%s( %L ), current_user
        ON CONFLICT DO NOTHING', __context_id, _state_provider, _state_provider, _context
    );

    IF NOT hive.app_is_forking( _context ) THEN
        RETURN;
    END IF;

    -- register tables
    PERFORM
          hive.app_register_table( 'hive_data', unnest( hsp.tables ), _context )
        , hive.grant_select_for_state_providers_table( unnest( hsp.tables ) )
    FROM hive_data.state_providers_registered hsp
    WHERE hsp.context_id = __context_id AND hsp.state_provider = _state_provider;

END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.app_state_providers_update( _first_block hive_data.blocks.num%TYPE, _last_block hive_data.blocks.num%TYPE, _context hive_data.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive_data.contexts.id%TYPE;
    __is_attached BOOL;
    __current_block_num hive_data.blocks.num%TYPE;
BEGIN
    SELECT hac.id, hca.is_attached, hac.current_block_num
    FROM hive_data.contexts hac
    JOIN hive_data.contexts_attachment hca ON hac.id = hca.context_id
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

    PERFORM hive.update_one_state_providers( _first_block, _last_block, hsp.state_provider, _context )
    FROM hive_data.state_providers_registered hsp
    WHERE hsp.context_id = __context_id;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_state_provider_drop( _state_provider hive_data.state_providers, _context hive_data.context_name )
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

    DELETE FROM hive_data.state_providers_registered hsp
        USING hive_data.contexts hc
    WHERE hc.name = _context AND hsp.state_provider = _state_provider AND hc.id = hsp.context_id;

    UPDATE hive_data.contexts
    SET last_active_at = NOW()
    WHERE name = _context;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_state_provider_drop_all( _context hive_data.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_state_provider_drop( hsp.state_provider, _context )
    FROM hive_data.state_providers_registered hsp
    JOIN hive_data.contexts hc ON hc.id = hsp.context_id
    WHERE hc.name = _context;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_wait_for_ready_instance(IN _context_name hive_data.context_name, IN _timeout INTERVAL DEFAULT '5 min'::INTERVAL, IN _wait_time INTERVAL DEFAULT '500 ms'::INTERVAL)
  RETURNS VOID
  LANGUAGE plpgsql
  VOLATILE
AS
$BODY$
BEGIN
  PERFORM hive.wait_for_ready_instance(ARRAY[_context_name], _timeout, _wait_time);
END
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_wait_for_ready_instance(IN _contexts hive.contexts_group, IN _timeout INTERVAL DEFAULT '5 min'::INTERVAL, IN _wait_time INTERVAL DEFAULT '500 ms'::INTERVAL)
  RETURNS VOID
  LANGUAGE plpgsql
  VOLATILE
AS
$BODY$
BEGIN
  PERFORM hive.wait_for_ready_instance(_contexts, _timeout, _wait_time);
END
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_check_contexts_synchronized( _contexts hive.contexts_group )
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
                 , hca.is_attached
                 , ctx.events_id
                 , ctx.is_forking
                 , (ctx.loop).size_of_blocks_batch
                 , (ctx.loop).current_batch_end
                 , (ctx.loop).end_block_range
        )
    ) INTO __number_of_rows
    FROM hive_data.contexts ctx
    JOIN hive_data.contexts_attachment hca ON hca.context_id = ctx.id
    WHERE ctx.name =ANY(_contexts);

    IF __number_of_rows != 1 THEN
        RAISE EXCEPTION 'Contexts % are not synchronized', _contexts;
    END IF;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.is_app_in_sync( _contexts hive.contexts_group  )
    RETURNS BOOLEAN
    LANGUAGE 'plpgsql'
    STABLE
AS
$BODY$
BEGIN
    RETURN COALESCE((SELECT BOOL_AND(hc.id IS NOT NULL AND hca.is_attached AND consistent_block - hc.current_block_num <= 1)
                     FROM UNNEST(_contexts) AS context_names(name)
                     LEFT JOIN hive_data.contexts hc USING(name)
                     JOIN hive_data.contexts_attachment hca ON hca.context_id = hc.id
                     CROSS JOIN hive_data.irreversible_data), FALSE);
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.is_app_in_sync( _context hive_data.context_name )
    RETURNS BOOLEAN
    LANGUAGE 'plpgsql'
    STABLE
AS
$BODY$
BEGIN
    RETURN hive.is_app_in_sync( ARRAY[ _context ] );
END;
$BODY$
;
