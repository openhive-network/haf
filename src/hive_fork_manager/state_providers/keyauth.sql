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
    __current_table_name TEXT := hive.get_keyauth_provider_table_name(_context);
    __template TEXT;
    __extra_indexes TEXT;
    __SELECT_placeholder TEXT;
    __ON_CONFLICT_placeholder TEXT;
BEGIN

    __context_id = hive.get_context_id( _context );

    __template = $t$ DROP TABLE IF EXISTS hive.%I 
                 $t$;
    EXECUTE format(__template, __current_table_name);


    __template =    $$
                        CREATE TABLE hive.%I(   -- table_name
                        account_name TEXT
                        , key_kind hive.key_type
                        , key_auth TEXT[]
                        , account_auth TEXT []
                        , op_id  BIGINT NOT NULL
                        , block_num INTEGER NOT NULL
                        , timestamp TIMESTAMP NOT NULL
                        %s                      -- extra_indexes
                        );
                    $$;

    __extra_indexes = $$ , CONSTRAINT pk_%s_keyauth PRIMARY KEY  ( key_auth, key_kind ) $$;
    __extra_indexes = format(__extra_indexes, _context);

    EXECUTE format(__template, __current_table_name, __extra_indexes);



    __template = $t$
        CREATE OR REPLACE FUNCTION %s(
            _first_block hive.blocks.num%%TYPE,
            _last_block hive.blocks.num%%TYPE
        ) RETURNS VOID AS $$
        BEGIN
            INSERT INTO hive.%I                                             -- __current_table_name
            SELECT %s                                                       -- SELECT_placeholder
            (hive.get_keyauths(ov.body_binary)).*, id, block_num, timestamp
            FROM hive.%s_operations_view ov                                 -- _context
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
            %s                                                               -- ON_CONFLICT_placeholder
            ;
        END
        $$ LANGUAGE plpgsql;
    $t$;


    -- For the main table
    __SELECT_placeholder =  $$
                                DISTINCT ON (key_auth, key_kind)
                            $$;
    
    __ON_CONFLICT_placeholder = $$
                                    ORDER BY key_auth, key_kind, timestamp DESC 
                                    ON CONFLICT ON CONSTRAINT pk_%s_keyauth 
                                    DO UPDATE SET
                                    account_name = EXCLUDED.account_name,
                                    key_auth = EXCLUDED.key_auth,
                                    account_auth = EXCLUDED.account_auth,
                                    op_id = EXCLUDED.op_id,
                                    block_num = EXCLUDED.block_num,
                                    timestamp = EXCLUDED.timestamp
                                $$;
    __ON_CONFLICT_placeholder = format(__ON_CONFLICT_placeholder, _context);

    EXECUTE format(__template, 'hive.insert_into_' || __current_table_name, __current_table_name,  __SELECT_placeholder, _context, __ON_CONFLICT_placeholder);


    RETURN ARRAY[ __current_table_name ];
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
    __current_table_name TEXT := hive.get_keyauth_provider_table_name(_context);
    __template TEXT;
BEGIN

    __context_id = hive.get_context_id( _context );

    __template = $t$ SELECT hive.insert_into_%s(%L, %L) $t$; 
    EXECUTE format(__template, __current_table_name, _first_block, _last_block);

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
    __current_table_name TEXT := hive.get_keyauth_provider_table_name(_context);
    __template TEXT;
BEGIN
    __context_id = hive.get_context_id( _context );

    __template =    $$
                        DROP TABLE hive.%I
                    $$;
    EXECUTE format(__template, __current_table_name );

    __template =    $$
                        DROP FUNCTION IF EXISTS %I
                    $$;
    EXECUTE format(__template, 'hive.insert_into_' ||  __current_table_name);
   
END;
$BODY$
;

-- helpers 
CREATE OR REPLACE FUNCTION hive.get_keyauth_provider_table_name(_context TEXT) 
RETURNS TEXT 
LANGUAGE plpgsql 
IMMUTABLE AS $BODY$
BEGIN
    RETURN '' || _context || '_keyauth';
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.get_keyauth_provider_history_table_name(_context TEXT) 
RETURNS TEXT 
LANGUAGE plpgsql 
IMMUTABLE AS $BODY$
BEGIN
    RETURN 'history_' || _context || '_keyauth';
END;
$BODY$;
