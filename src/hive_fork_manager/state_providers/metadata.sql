CREATE OR REPLACE FUNCTION hive.start_provider_metadata( _context hive.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_metadata';
BEGIN

    __context_id = hive.get_context_id( _context );


    IF __context_id IS NULL THEN
         RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format('DROP TABLE IF EXISTS hive.%I', __table_name);

    EXECUTE format( 'CREATE TABLE hive.%I(
                       account_id INTEGER
                     , json_metadata TEXT DEFAULT ''''
                     , posting_json_metadata TEXT DEFAULT ''''
                   , PRIMARY KEY ( account_id )
                   )', __table_name);
    RETURN ARRAY[ __table_name ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_state_provider_metadata(
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
    __table_name TEXT := _context || '_metadata';
    __to_execute TEXT;
    __to_execute_posting TEXT;
BEGIN
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;
  __to_execute =  format('
    WITH select_metadata AS MATERIALIZED (
    SELECT 
        (hive.get_metadata(ov.body_binary)).*,
        ov.id
    FROM 
        hive.%s_operations_view ov
    WHERE
        ov.op_type_id in (
		SELECT id FROM hive.operation_types WHERE name IN
			(''hive::protocol::account_create_operation'',
			 ''hive::protocol::account_update_operation'',
			 ''hive::protocol::create_claimed_account_operation'',
			 ''hive::protocol::account_create_with_delegation_operation'',
			 ''hive::protocol::account_update2_operation''))
        AND ov.block_num BETWEEN %s AND %s
    ) 
    INSERT INTO
        hive.%s_metadata(account_id, json_metadata)
    SELECT
        accounts_view.id,
        json_metadata
    FROM
        (
            SELECT
                DISTINCT ON (metadata.account_name) metadata.account_name,
                metadata.json_metadata
            FROM select_metadata as metadata
            WHERE metadata.json_metadata != ''''
            ORDER BY 
                metadata.account_name,
                metadata.id DESC
        ) as t
        JOIN hive.accounts_view accounts_view ON accounts_view.name = account_name 
    ON CONFLICT (account_id) DO UPDATE
    SET
        json_metadata = EXCLUDED.json_metadata;'
    , _context, _first_block, _last_block,  _context
    );

    __to_execute_posting =  format('
    WITH select_metadata AS MATERIALIZED (
    SELECT 
        (hive.get_metadata(ov.body_binary)).*,
        ov.id
    FROM 
        hive.%s_operations_view ov
    WHERE
        ov.op_type_id in (
		SELECT id FROM hive.operation_types WHERE name IN
			(''hive::protocol::account_create_operation'',
			 ''hive::protocol::account_update_operation'',
			 ''hive::protocol::create_claimed_account_operation'',
			 ''hive::protocol::account_create_with_delegation_operation'',
			 ''hive::protocol::account_update2_operation''))
        AND ov.block_num BETWEEN %s AND %s
    )   
    INSERT INTO
        hive.%s_metadata(account_id, posting_json_metadata)
    SELECT
        accounts_view.id,
        posting_json_metadata
    FROM
        (
            SELECT
                DISTINCT ON (metadata.account_name) metadata.account_name,
                metadata.posting_json_metadata
            FROM select_metadata as metadata
            WHERE metadata.posting_json_metadata != ''''
            ORDER BY 
                metadata.account_name,
                metadata.id DESC
        ) as t
        JOIN hive.accounts_view accounts_view ON accounts_view.name = account_name 
    ON CONFLICT (account_id) DO UPDATE
    SET
        posting_json_metadata = EXCLUDED.posting_json_metadata;'
    , _context, _first_block, _last_block,  _context
        );

    EXECUTE __to_execute;
    EXECUTE __to_execute_posting;

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_state_provider_metadata( _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_metadata';
BEGIN
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'DROP TABLE hive.%I', __table_name );
END;
$BODY$
;
