DROP FUNCTION if exists  hive.start_provider_c_a_b_s_t;
CREATE OR REPLACE FUNCTION hive.start_provider_c_a_b_s_t( _context hive.context_name, _shared_memory_bin_path TEXT)
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_c_a_b_s_t';
    __config_table_name TEXT := _context || '_c_a_b_s_t_config';
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

    EXECUTE format('CREATE TABLE hive.%I (shared_memory_bin_path TEXT)', __config_table_name);

    EXECUTE format('INSERT INTO hive.%I VALUES (%L)', __config_table_name, _shared_memory_bin_path);

    RETURN ARRAY[ __table_name,  __config_table_name ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_state_provider_c_a_b_s_t(
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
    __table_name TEXT := _context || '_c_a_b_s_t';
    __config_table_name TEXT := _context || '_c_a_b_s_t_config';
    __get_balances TEXT;
    __database_name TEXT;
    __postgres_url TEXT;
	__current_pid INT;
    __shared_memory_bin_path TEXT;
    __consensus_state_provider_replay_call_ok BOOLEAN;
BEGIN
    __current_pid =  pg_backend_pid();
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format('TRUNCATE TABLE hive.%s', __table_name);

    
    RAISE NOTICE 'consensus_state_provider_replay';

    SELECT datname AS database_name FROM pg_stat_activity WHERE pid = __current_pid INTO __database_name;

    __postgres_url = 'postgres:///' || __database_name;
    raise notice '__postgres_url=%', __postgres_url;
    
    EXECUTE format('SELECT * FROM hive.%s ', __config_table_name) INTO __shared_memory_bin_path;
    raise notice '__shared_memory_bin_path=%', __shared_memory_bin_path;


    __consensus_state_provider_replay_call_ok = (SELECT hive.consensus_state_provider_replay(_first_block, _last_block, _context , __postgres_url, __shared_memory_bin_path));

    RAISE NOTICE '__consensus_state_provider_replay_call_ok=%', __consensus_state_provider_replay_call_ok;

    -- mtlk TODO remove below, maybe move upwards
IF TRUE THEN -- mtlk try_grab_operations
    raise notice 'Accounts 15 richest=%', E'\n' || 
    (
        SELECT json_agg(t)
        FROM (
                SELECT *
                FROM hive.current_all_accounts_balances_C(_context) ORDER BY balance DESC LIMIT 15 
            ) t
    );


    __get_balances = format('INSERT INTO hive.%I SELECT * FROM hive.current_all_accounts_balances_C(%L);', __table_name, _context);
    EXECUTE __get_balances;
END IF;

END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.drop_state_provider_c_a_b_s_t( _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_c_a_b_s_t';
    __config_table_name TEXT := _context || '_c_a_b_s_t_config';
    __shared_memory_bin_path TEXT;
BEGIN
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format('SELECT * FROM hive.%s ', __config_table_name) INTO __shared_memory_bin_path;
    raise notice '__shared_memory_bin_path=%', __shared_memory_bin_path;

    EXECUTE format( 'DROP TABLE hive.%I', __table_name );
    EXECUTE format( 'DROP TABLE hive.%I', __config_table_name );

    PERFORM hive.consensus_state_provider_finish('context', __shared_memory_bin_path);
END;
$BODY$
;
