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
    __table_name TEXT := '' || _context || '_keyauth';
    __table_name_history TEXT := 'history_' || _context || '_keyauth';
    __format TEXT;
BEGIN

    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
    INTO __context_id;


    IF __context_id IS NULL THEN
         RAISE EXCEPTION 'No context with name %', _context;
    END IF;


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
                     , op_id  BIGINT NOT NULL
                     , block_num INTEGER NOT NULL
                     , timestamp TIMESTAMP NOT NULL
                   , PRIMARY KEY ( key_auth, key_kind )
                   )', __table_name);
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
    __table_name TEXT := '' || _context || '_keyauth';
    __table_name_history TEXT := 'history_' || _context || '_keyauth';
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

    EXECUTE format(
        'INSERT INTO hive.%I
        SELECT (hive.get_keyauths( ov.body_binary )).* , id, block_num, timestamp
        FROM hive.%s_operations_view ov
        WHERE
            ov.op_type_id in 
            (
                SELECT id FROM hive.operation_types WHERE name IN
                (
                    ''hive::protocol::account_create_operation'', 
                    ''hive::protocol::account_create_with_delegation_operation'',
                    ''hive::protocol::account_update_operation'',
                    ''hive::protocol::account_update2_operation'',
                    ''hive::protocol::create_claimed_account_operation'',
                    ''hive::protocol::recover_account_operation'',
                    ''hive::protocol::reset_account_operation'',
                    ''hive::protocol::witness_set_properties_operation''
                )
            )
            AND 
                ov.block_num BETWEEN %s AND %s
        ON CONFLICT DO NOTHING'
        , __table_name, _context, _first_block, _last_block
    );

    EXECUTE format(
        'INSERT INTO hive.%I
        SELECT (hive.get_keyauths( ov.body_binary )).* , id, block_num, timestamp
        FROM hive.%s_operations_view ov
        WHERE
            ov.op_type_id in 
            (
                SELECT id FROM hive.operation_types WHERE name IN
                (
                    ''hive::protocol::account_create_operation'', 
                    ''hive::protocol::account_create_with_delegation_operation'',
                    ''hive::protocol::account_update_operation'',
                    ''hive::protocol::account_update2_operation'',
                    ''hive::protocol::create_claimed_account_operation'',
                    ''hive::protocol::recover_account_operation'',
                    ''hive::protocol::request_account_recovery_operation'',
                    ''hive::protocol::reset_account_operation'',
                    ''hive::protocol::witness_set_properties_operation''
                )
            )
            AND 
                ov.block_num BETWEEN %s AND %s
        ON CONFLICT DO NOTHING'
        , __table_name_history, _context, _first_block, _last_block
    );

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
    __table_name TEXT := '' || _context || '_keyauth';
    __table_name_history TEXT := 'history_' || _context || '_keyauth';
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
END;
$BODY$
;
