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

    RETURN ARRAY[ __table_name ];
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
    __get_balances TEXT;
    __database_name TEXT;
    __postgres_url TEXT;
	__current_pid INT;
BEGIN
    __current_pid =  pg_backend_pid();
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format('TRUNCATE TABLE hive.%s', __table_name);

    
    RAISE NOTICE 'consensus_state_provider_replay';

        select datname as database_name from pg_stat_activity where pid = __current_pid INTO __database_name;

    __postgres_url = 'postgres:///' || __database_name;
    raise notice '__postgres_url=%', __postgres_url;


    PERFORM hive.consensus_state_provider_replay(_first_block, _last_block, _context , __postgres_url);

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
BEGIN
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'DROP TABLE hive.%I', __table_name );

    PERFORM hive.consensus_state_provider_finish('context');
END;
$BODY$
;
