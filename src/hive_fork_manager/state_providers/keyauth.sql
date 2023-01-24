/*
Operations that may include key_auths 
account_create
account_create_with_delegation
account_update
account_update2_operation
condenser_api.lookup_account_names ?
create_claimed_account 
database_api.find_accounts ?
database_api.list_accounts ?
database_api.list_owner_histories ?
recover_account
request_account_recovery
witness_set_properties_operation
custom_binary_operation ?
reset_account_operation
*/

CREATE OR REPLACE FUNCTION hive.start_provider_keyauth( _context hive.context_name, _dummy_arg1 TEXT DEFAULT '')
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_keyauth';
BEGIN

    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
    INTO __context_id;


    IF __context_id IS NULL THEN
         RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    
    EXECUTE format('DROP TABLE IF EXISTS hive.%I', __table_name);

    EXECUTE format( 'CREATE TABLE hive.%I(
                       key_auth TEXT
                     , authority_kind hive.authority_type
                     , account_name TEXT
                   , PRIMARY KEY ( key_auth, authority_kind )
                   )', __table_name);

    RETURN ARRAY[ __table_name ];
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
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_keyauth';
BEGIN
    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
        INTO __context_id;

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format(
        'INSERT INTO hive.%s_keyauth 
        SELECT (hive.get_keyauths( ov.body )).*
        FROM hive.%s_operations_view ov
        WHERE
                hive.is_keyauths_operation(ov.body)
            AND 
                ov.block_num BETWEEN %s AND %s
        ON CONFLICT DO NOTHING'
        , _context, _context, _first_block, _last_block
    );
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
    __table_name TEXT := _context || '_keyauth';
BEGIN
    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
    INTO __context_id;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'DROP TABLE hive.%I', __table_name );
END;
$BODY$
;
