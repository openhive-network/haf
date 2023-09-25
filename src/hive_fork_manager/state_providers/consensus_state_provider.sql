DROP FUNCTION if exists  hive.start_provider_csp;
CREATE OR REPLACE FUNCTION hive.start_provider_csp( _context hive.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_csp';
    __disconnect_function TEXT;
    __reconnect_string TEXT;
    __shared_memory_bin_path TEXT := (SELECT hive.get_shmem_path(_context));
BEGIN


    RAISE NOTICE 'get_shmem_path=%', (SELECT hive.get_shmem_path(_context));

    __context_id = hive.get_context_id( _context );


    IF __context_id IS NULL THEN
         RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format('DROP TABLE IF EXISTS hive.%I', __table_name);

    EXECUTE format('CREATE TABLE hive.%I 
                   (    account                 CHAR(16),
                        balance                 BIGINT,
                        hbd_balance             BIGINT,
                        vesting_shares          BIGINT,
                        savings_hbd_balance     BIGINT,
                        reward_hbd_balance      BIGINT,
                        PRIMARY KEY ( account )
                   )', __table_name);

    --EXECUTE format('DROP TABLE IF EXISTS hive.%I', __config_table_name);

    
    -- -- mtlk to remove in session
    -- EXECUTE format('CREATE TABLE hive.%I (shared_memory_bin_path TEXT)', __config_table_name);

    -- -- mtlk to remove in session
    -- EXECUTE format('INSERT INTO hive.%I VALUES (%L)', __config_table_name, __shared_memory_bin_path);

    

    __reconnect_string = format('SELECT hive.csp_init(%L, %L, %L)', _context, __shared_memory_bin_path, hive.get_postgres_url());

    __disconnect_function = 'SELECT hive.csp_finish(%s)';

    PERFORM hive.session_setup(
        _context, 
         __reconnect_string,
         __disconnect_function
    );

    PERFORM hive.session_managed_object_start(_context);

    RETURN ARRAY[ __table_name ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_state_provider_csp(
    _first_block hive.blocks.num%TYPE,
    _last_block hive.blocks.num%TYPE,
    _context hive.context_name)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_csp';
    __get_balances TEXT;
    __database_name TEXT;
    __postgres_url TEXT;
    __current_pid INT;
    __shared_memory_bin_path TEXT := hive.get_shmem_path(_context);
    __consensus_state_provider_replay_call_ok BOOLEAN;
    __session_ptr BIGINT;
BEGIN
    __current_pid =  pg_backend_pid();
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format('TRUNCATE TABLE hive.%s', __table_name);

    RAISE NOTICE 'consensus_state_provider_replay';

    SELECT datname AS database_name FROM pg_stat_activity WHERE pid = __current_pid INTO __database_name;

    __postgres_url := hive.get_postgres_url();

    







     __session_ptr = hive.session_get_managed_object_handle(_context);
    __consensus_state_provider_replay_call_ok = (SELECT hive.consensus_state_provider_replay(__session_ptr, _first_block, _last_block));

    RAISE NOTICE '__consensus_state_provider_replay_call_ok=%', __consensus_state_provider_replay_call_ok;

    PERFORM hive.update_accounts_table(__session_ptr, __table_name);

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_accounts_table(IN _session_ptr BIGINT, IN _table_name TEXT)
RETURNS void
LANGUAGE plpgsql
VOLATILE
AS
$BODY$
DECLARE
    __get_balances TEXT;
    __top_richest_accounts_json TEXT;
BEGIN
    __get_balances := format('INSERT INTO hive.%I SELECT * FROM hive.current_all_accounts_balances(%L)', _table_name, _session_ptr);
    EXECUTE __get_balances;

    EXECUTE format('
        SELECT json_agg(t)
        FROM (
            SELECT *
            FROM hive.%I
            ORDER BY balance DESC
            LIMIT 15
        ) t
    ', _table_name) INTO __top_richest_accounts_json;

    RAISE NOTICE 'Accounts 15 richest=%', E'\n' || __top_richest_accounts_json;

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_state_provider_csp( _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_csp';
    __shared_memory_bin_path TEXT := hive.get_shmem_path(_context);
    __session_ptr BIGINT;
BEGIN
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    raise notice '__shared_memory_bin_path=%', __shared_memory_bin_path;


    __session_ptr = hive.session_get_managed_object_handle(_context);

    -- wipe clean
    PERFORM hive.csp_finish(__session_ptr, TRUE); 

    --delete session entry from the sessions table
    PERFORM hive.session_forget(_context);

    EXECUTE format( 'DROP TABLE hive.%I', __table_name );
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.get_shmem_path(context TEXT) RETURNS TEXT AS $$
DECLARE
    dir_path TEXT;
    combined_path TEXT;
    shmem_path TEXT;
BEGIN
    -- Fetch the dir_path from the tools function
    SELECT hive.get_tablespace_location() INTO dir_path;

    -- Erase the last segment
    SELECT regexp_replace(dir_path, '/[^/]*$', '') INTO dir_path;

    -- Combine dir_path with the context parameter
    combined_path := dir_path ||'/shmem/' || context || '-' || (SELECT uuid_generate_v4());

    RAISE NOTICE 'Returning from hive.get_shmem_path=%', combined_path;


    RETURN combined_path;
END;
$$ LANGUAGE plpgsql;