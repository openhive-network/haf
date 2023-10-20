-- In hive::protocol::recover_account_operation the entry recent_owner_authority is not recorded, only new_owner_authority
-- and the whole hive::protocol::request_account_recovery_operation is not recorded at all

CREATE OR REPLACE FUNCTION hive.start_provider_keyauth( _context hive.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := hive.get_keyauth_provider_table_name(_context);
    __table_name_history TEXT := hive.get_keyauth_provider_history_table_name(_context);
    __format TEXT;
    __template TEXT;
    __SELECT_placeholder TEXT;
    __ON_CONFLICT_placeholder TEXT;
BEGIN

    __context_id = hive.get_context_id( _context );

    __format = format('DROP TABLE IF EXISTS hive.%I', __table_name);
    RAISE NOTICE 'Executing: %', __format;
    EXECUTE __format;
    
    __format = format('DROP TABLE IF EXISTS hive.%I', __table_name_history);
    RAISE NOTICE 'Executing: %', __format;
    EXECUTE __format;

    __format = format( 'CREATE TABLE hive.%I(
                          account_name TEXT
                        , key_kind hive.key_type
                        , key_auth TEXT[]
                        , account_auth TEXT []
                        , op_id BIGINT NOT NULL
                        , block_num INTEGER NOT NULL
                        , timestamp TIMESTAMP NOT NULL
                      , CONSTRAINT pk_%s_keyauth PRIMARY KEY  ( key_auth, key_kind )
                    )', __table_name, _context);
    RAISE NOTICE 'Executing: %', __format;
    EXECUTE __format;

    __format = format( 'CREATE TABLE hive.%I(
                       account_name TEXT
                     , key_kind hive.key_type
                     , key_auth TEXT[]
                     , account_auth TEXT []
                     , op_id  BIGINT NOT NULL
                     , block_num INTEGER NOT NULL
                     , timestamp TIMESTAMP NOT NULL
                   )', __table_name_history);
    RAISE NOTICE 'Executing: %', __format;
    EXECUTE __format;

    --RAISE NOTICE 'START In hive.start_provider_keyauth: hive.context_keyauth TABLE contents: %', (E'\n' || (SELECT jsonb_pretty(json_agg(t)::jsonb) FROM (SELECT * from hive.context_keyauth)t));
    --RAISE NOTICE 'START In hive.start_provider_keyauth: hive.history_context_keyauth TABLE contents: %', (E'\n' || (SELECT jsonb_pretty(json_agg(t)::jsonb) FROM (SELECT * from hive.history_context_keyauth)t));

    __template = $t$
        CREATE OR REPLACE FUNCTION %s(
            _first_block hive.blocks.num%%TYPE,
            _last_block hive.blocks.num%%TYPE
        ) RETURNS VOID AS $$
        BEGIN
            INSERT INTO hive.%I
            %s -- SELECT_placeholder
            (hive.get_keyauths(ov.body_binary)).*, id, block_num, timestamp

            FROM hive.%s_operations_view ov
            WHERE
            ov.op_type_id in 
                (
                    SELECT id FROM hive.operation_types WHERE name IN
                    (
                        'hive::protocol::account_create_operation', 
                        'hive::protocol::account_create_with_delegation_operation',
                        'hive::protocol::account_update_operation',
                        'hive::protocol::account_update2_operation',
                        'hive::protocol::create_claimed_account_operation',
                        'hive::protocol::recover_account_operation',
                        'hive::protocol::request_account_recovery_operation',
                        'hive::protocol::witness_set_properties_operation'
                    )
                )
            AND ov.block_num BETWEEN _first_block AND _last_block
            %s -- ON_CONFLICT_placeholder
            ;
        END
        $$ LANGUAGE plpgsql;
    $t$;


    -- For the main table
    __SELECT_placeholder = $s$
        SELECT DISTINCT ON (key_auth, key_kind)
    $s$;
    
    __ON_CONFLICT_placeholder =$c$
        ORDER BY key_auth, key_kind, timestamp DESC 
        ON CONFLICT ON CONSTRAINT pk_%s_keyauth 
        DO UPDATE SET
        account_name = EXCLUDED.account_name,
        key_auth = EXCLUDED.key_auth,
        account_auth = EXCLUDED.account_auth,
        op_id = EXCLUDED.op_id,
        block_num = EXCLUDED.block_num,
        timestamp = EXCLUDED.timestamp
    $c$;
    __ON_CONFLICT_placeholder = format(__ON_CONFLICT_placeholder, _context);

    __format =  format(__template, 'hive.insert_into_' || __table_name, __table_name,  __SELECT_placeholder, _context, __ON_CONFLICT_placeholder, _context);
    EXECUTE __format;


    -- For the history table
    __SELECT_placeholder := $s$
        SELECT 
    $s$;
    __ON_CONFLICT_placeholder := $c$
        ON CONFLICT DO NOTHING
    $c$;

    __format =  format(__template, 'hive.insert_into_' || __table_name_history, __table_name_history,  __SELECT_placeholder, _context, __ON_CONFLICT_placeholder, _context);
    EXECUTE __format;

    RETURN ARRAY[ __table_name, __table_name_history ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_state_provider_keyauth(
    _first_block hive.blocks.num%TYPE,
    _last_block hive.blocks.num%TYPE,
    _context hive.context_name)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
    SET jit = OFF
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := hive.get_keyauth_provider_table_name(_context);
    __table_name_history TEXT := hive.get_keyauth_provider_history_table_name(_context);
BEGIN
    --RAISE NOTICE 'UPDATE begin In hive.update_state_provider_keyauth: hive.context_keyauth TABLE contents: %', (E'\n' || (SELECT jsonb_pretty(json_agg(t)::jsonb) FROM (SELECT * from hive.context_keyauth)t));
    --RAISE NOTICE 'UPDATE begin In hive.update_state_provider_keyauth: hive.history_context_keyauth TABLE contents: %', (E'\n' || (SELECT jsonb_pretty(json_agg(t)::jsonb) FROM (SELECT * from hive.history_context_keyauth)t));

    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
        INTO __context_id;

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format('SELECT hive.insert_into_%s(%s, %s);', __table_name, _first_block, _last_block);

    EXECUTE format('SELECT hive.insert_into_%s(%L, %L);',  __table_name_history, _first_block, _last_block);


    --RAISE NOTICE 'UPDATE end In hive.update_state_provider_keyauth: hive.context_keyauth TABLE contents: %', (E'\n' || (SELECT jsonb_pretty(json_agg(t)::jsonb) FROM (SELECT * from hive.context_keyauth)t));
    --RAISE NOTICE 'UPDATE end In hive.update_state_provider_keyauth: hive.history_context_keyauth TABLE contents: %', (E'\n' || (SELECT jsonb_pretty(json_agg(t)::jsonb) FROM (SELECT * from hive.history_context_keyauth)t));

END;
$BODY$
;
        
CREATE OR REPLACE FUNCTION hive.drop_state_provider_keyauth( _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := hive.get_keyauth_provider_table_name(_context);
    __table_name_history TEXT := hive.get_keyauth_provider_history_table_name(_context);
BEGIN
    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
    INTO __context_id;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'DROP TABLE hive.%I', __table_name );
    EXECUTE format( 'DROP TABLE hive.%I', __table_name_history );

    EXECUTE format(
        'DROP FUNCTION IF EXISTS %I;',
        'hive.insert_into_' ||  __table_name
    );

    EXECUTE format(
        'DROP FUNCTION IF EXISTS %I;',
        'hive.insert_into_' ||  __table_name_history
    );    
END;
$BODY$
;

-- helpers 
CREATE OR REPLACE FUNCTION hive.get_keyauth_provider_table_name(_context TEXT) 
RETURNS TEXT 
LANGUAGE plpgsql 
IMMUTABLE AS $$
BEGIN
    RETURN '' || _context || '_keyauth';
END;
$$;

CREATE OR REPLACE FUNCTION hive.get_keyauth_provider_history_table_name(_context TEXT) 
RETURNS TEXT 
LANGUAGE plpgsql 
IMMUTABLE AS $$
BEGIN
    RETURN 'history_' || _context || '_keyauth';
END;
$$;
