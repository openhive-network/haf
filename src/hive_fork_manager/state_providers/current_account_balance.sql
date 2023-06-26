DROP FUNCTION if exists  hive.start_provider_current_account_balance_state_provider;
CREATE OR REPLACE FUNCTION hive.start_provider_current_account_balance_state_provider( _context hive.context_name, _shared_memory_bin_path TEXT)
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_current_account_balance_state_provider';
    __config_table_name TEXT := _context || '_current_account_balance_state_provider_config';
    __handle BIGINT;
    __disconnect_function TEXT;
    __reconnect_string TEXT;
BEGIN

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

    EXECUTE format('DROP TABLE IF EXISTS hive.%I', __config_table_name);

    
    -- mtlk to remove in session
    EXECUTE format('CREATE TABLE hive.%I (shared_memory_bin_path TEXT)', __config_table_name);

    -- mtlk to remove in session
    EXECUTE format('INSERT INTO hive.%I VALUES (%L)', __config_table_name, _shared_memory_bin_path);

    
    __handle = (SELECT hive.csp_init(_context,_shared_memory_bin_path, hive.get_postgres_url()));

    __reconnect_string = format('SELECT hive.csp_init(%L, %L, %L)', _context,_shared_memory_bin_path, hive.get_postgres_url());

    __disconnect_function = 'SELECT hive.csp_finish(%s)';

    PERFORM hive.create_session(
        _context, 
        jsonb_build_object(       
            'shared_memory_bin_path', _shared_memory_bin_path,
            'postgres_url', hive.get_postgres_url(),
            'reconnect_string', __reconnect_string,
            'disconnect_function', __disconnect_function,
            'session_handle', __handle
        )
    );

    RETURN ARRAY[ __table_name,  __config_table_name ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_state_provider_current_account_balance_state_provider(
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
    __table_name TEXT := _context || '_current_account_balance_state_provider';
    __config_table_name TEXT := _context || '_current_account_balance_state_provider_config';
    __get_balances TEXT;
    __database_name TEXT;
    __postgres_url TEXT;
    __current_pid INT;
    __shared_memory_bin_path TEXT;
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

    __shared_memory_bin_path := hive.get_shared_memory_bin_path(__config_table_name);







     __session_ptr = hive.get_session_ptr(_context);
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


CREATE OR REPLACE FUNCTION hive.get_shared_memory_bin_path(_config_table_name TEXT)
    RETURNS TEXT
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __shared_memory_bin_path TEXT;
BEGIN
    EXECUTE format('SELECT * FROM hive.%s', _config_table_name) INTO __shared_memory_bin_path;
    RAISE NOTICE '__shared_memory_bin_path=%', __shared_memory_bin_path;
    RETURN __shared_memory_bin_path;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_state_provider_current_account_balance_state_provider( _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_current_account_balance_state_provider';
    __config_table_name TEXT := _context || '_current_account_balance_state_provider_config';
    __shared_memory_bin_path TEXT;
    __session_ptr BIGINT;
BEGIN
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format('SELECT * FROM hive.%s ', __config_table_name) INTO __shared_memory_bin_path;
    raise notice '__shared_memory_bin_path=%', __shared_memory_bin_path;

    EXECUTE format( 'DROP TABLE hive.%I', __table_name );
    EXECUTE format( 'DROP TABLE hive.%I', __config_table_name );

    __session_ptr = hive.get_session_ptr(_context);

    -- wipe clean
    PERFORM hive.csp_finish(__session_ptr, _wipe_clean_shared_memory_bin := TRUE); 

    --delete session entry from the sessions table
    PERFORM hive.destroy_session(_context);

END;
$BODY$
;
