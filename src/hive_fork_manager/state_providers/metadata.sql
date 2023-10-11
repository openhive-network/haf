CREATE OR REPLACE FUNCTION hive.get_metadata_update_function_name( _context hive.context_name )
    RETURNS TEXT
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN format( 'hive.%I_metadata_update', _context );
END
$BODY$;

CREATE OR REPLACE FUNCTION hive.get_metadata_posting_function_name( _context hive.context_name )
    RETURNS TEXT
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN format( 'hive.%I_metadata_update_posting', _context );
END
$BODY$;

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

    EXECUTE format(
    'CREATE OR REPLACE FUNCTION %I( _blockFrom INT, _blockTo INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
    AS
    $$
    BEGIN
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
            AND ov.block_num BETWEEN _blockFrom AND _blockTo
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
            json_metadata = EXCLUDED.json_metadata;
    END
    $$;'
    , hive.get_metadata_update_function_name( _context ), _context, _context
    );

    EXECUTE format('
    CREATE OR REPLACE FUNCTION %I(_blockFrom INT, _blockTo INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
    AS
    $$
    BEGIN
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
            AND ov.block_num BETWEEN _blockFrom AND _blockTo
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
        SET posting_json_metadata = EXCLUDED.posting_json_metadata;
    END
    $$;'
    , hive.get_metadata_posting_function_name( _context ), _context, _context
    );

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
    SET jit = OFF
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
    EXECUTE format(
          'SELECT %I(%s, %s);'
        , hive.get_metadata_update_function_name( _context )
        , _first_block
        , _last_block
    );

    EXECUTE format(
          'SELECT %I(%s, %s);'
        , hive.get_metadata_posting_function_name( _context )
        , _first_block
        , _last_block
    );
END
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
    EXECUTE format(
          'DROP FUNCTION IF EXISTS %I'
        , hive.get_metadata_update_function_name( _context )
    );

    EXECUTE format(
          'DROP FUNCTION IF EXISTS %I'
        , hive.get_metadata_posting_function_name( _context )
    );
END;
$BODY$
;
