DROP FUNCTION IF EXISTS hive.start_provider_csp;
CREATE OR REPLACE FUNCTION hive.start_provider_csp( _context hive.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_csp';
    __disconnect_command TEXT;
    __reconnect_command TEXT;
    __shared_memory_bin_dir TEXT := (SELECT hive.get_shared_memory_bin_dir(_context));
BEGIN

    __context_id = hive.get_context_id( _context );

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

    __reconnect_command = format('SELECT hive.csp_init(%L, %L, %L)', _context, __shared_memory_bin_dir, hive.get_postgres_url());

    __disconnect_command = 'SELECT hive.csp_finish(%s)';

    PERFORM hive.session_setup(
        _context, 
         __reconnect_command,
         __disconnect_command
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
    __database_name TEXT;
    __postgres_url TEXT;
    __current_pid INT;
    __consensus_state_provider_replay_call_ok BOOLEAN;
    __session_ptr BIGINT;
BEGIN
    __current_pid =  pg_backend_pid();
    __context_id = hive.get_context_id( _context );

    EXECUTE format('TRUNCATE TABLE hive.%s', __table_name);

    SELECT datname AS database_name FROM pg_stat_activity WHERE pid = __current_pid INTO __database_name;

    __postgres_url := hive.get_postgres_url();
    __session_ptr = hive.session_get_managed_object_handle(_context);
    __consensus_state_provider_replay_call_ok = (SELECT hive.consensus_state_provider_replay(__session_ptr, _first_block, _last_block));
    ASSERT __consensus_state_provider_replay_call_ok, 'hive.consensus_state_provider_replay should return TRUE';

    PERFORM hive.update_csp_balances_table(__session_ptr, __table_name);

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_csp_balances_table(IN _session_ptr BIGINT, IN _table_name TEXT)
RETURNS void
LANGUAGE plpgsql
VOLATILE
AS
$BODY$
DECLARE
    __get_balances TEXT;
BEGIN
    __get_balances := format('INSERT INTO hive.%I SELECT * FROM hive.current_all_accounts_balances(%L)', _table_name, _session_ptr);
    EXECUTE __get_balances;
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
    __session_ptr BIGINT;
BEGIN
    __context_id = hive.get_context_id( _context );

    __session_ptr = hive.session_get_managed_object_handle(_context);

    -- Wipe clean
    PERFORM hive.csp_finish(__session_ptr, TRUE); 

    -- Delete session entry from the sessions table
    PERFORM hive.session_forget(_context);

    EXECUTE format( 'DROP TABLE hive.%I', __table_name );
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.get_shared_memory_bin_dir(context TEXT) RETURNS TEXT AS $$
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
    combined_path := dir_path ||'/consensus_state_provider_shared_memory_bin_dir/' || context || '-' || (SELECT uuid_generate_v4());

    RETURN combined_path;
END;
$$ LANGUAGE plpgsql;
