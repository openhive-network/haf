CREATE OR REPLACE FUNCTION hive.get_metadata_update_function_name( _context hafd.context_name )
    RETURNS TEXT
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN format( '%I_metadata_update', _context );
END
$BODY$;

CREATE OR REPLACE FUNCTION hive.start_provider_metadata( _context hafd.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hafd.contexts.id%TYPE;
    __table_name TEXT := _context || '_metadata';
    __schema TEXT;
BEGIN

    __context_id = hive.get_context_id( _context );
    SELECT hc.schema INTo __schema
    FROM hafd.contexts hc
    WHERE hc.id = __context_id;


    IF __context_id IS NULL THEN
         RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format('DROP TABLE IF EXISTS hafd.%I', __table_name);

    EXECUTE format( 'CREATE TABLE hafd.%I(
                       account_id INTEGER
                     , json_metadata TEXT DEFAULT ''''
                     , posting_json_metadata TEXT DEFAULT ''''
                   , PRIMARY KEY ( account_id )
                   )', __table_name);

    RETURN ARRAY[ __table_name ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.runtimecode_provider_metadata( _context hafd.context_name )
    RETURNS VOID
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context;

    EXECUTE format(
            'CREATE OR REPLACE FUNCTION hive.%I( _blockFrom INT, _blockTo INT )
            RETURNS void
            LANGUAGE plpgsql
            VOLATILE
            AS
            $$
            DECLARE
                __state INT := 0;
            BEGIN

                IF COALESCE( ( SELECT _blockFrom > block_num FROM hafd.applied_hardforks WHERE hardfork_num = 21 ), FALSE ) THEN
                    __state := 1;
                ELSIF COALESCE( ( SELECT _blockTo <= block_num FROM hafd.applied_hardforks WHERE hardfork_num = 21 ), FALSE ) THEN
                    __state := -1;
                END IF;

                WITH select_metadata AS MATERIALIZED (
                SELECT
                    ov.body_binary,
                    ov.id,
                    ov.block_num
                FROM
                    %s.operations_view ov
                WHERE
                    ov.op_type_id in (
                    SELECT id FROM hafd.operation_types WHERE name IN
                        (''hive::protocol::account_create_operation'',
                         ''hive::protocol::account_update_operation'',
                         ''hive::protocol::create_claimed_account_operation'',
                         ''hive::protocol::account_create_with_delegation_operation'',
                         ''hive::protocol::account_update2_operation''))
                    AND ov.block_num BETWEEN _blockFrom AND _blockTo
                ), calculated_metadata AS MATERIALIZED
                (
                    SELECT
                        (hive.get_metadata
                        (
                            sm.body_binary,
                            CASE __state
                                WHEN  1 THEN TRUE
                                WHEN  0 THEN COALESCE( ( SELECT block_num < sm.block_num FROM hafd.applied_hardforks WHERE hardfork_num = 21 ), FALSE )
                                WHEN -1 THEN FALSE
                            END
                        )).*,
                        sm.id
                    FROM select_metadata sm
                ),
                prepare_accounts AS MATERIALIZED
                (
                SELECT
                    metadata.account_name
                FROM calculated_metadata as metadata
                GROUP BY metadata.account_name
                ),
                select_json_metadata AS MATERIALIZED
                (
                SELECT
                    DISTINCT ON (metadata.account_name) metadata.account_name,
                    metadata.json_metadata
                FROM calculated_metadata as metadata
                WHERE metadata.json_metadata != ''''
                ORDER BY
                    metadata.account_name,
                    metadata.id DESC
                ),
                select_posting_json_metadata AS MATERIALIZED
                (
                SELECT
                    DISTINCT ON (metadata.account_name) metadata.account_name,
                    metadata.posting_json_metadata
                FROM calculated_metadata as metadata
                WHERE metadata.posting_json_metadata != ''''
                ORDER BY
                    metadata.account_name,
                    metadata.id DESC
                )
                INSERT INTO
                    hafd.%s_metadata(account_id, json_metadata, posting_json_metadata)
                SELECT
                    av.id,
                    COALESCE(sjm.json_metadata, ''''),
                    COALESCE(pjm.posting_json_metadata, '''')
                FROM prepare_accounts pa
                LEFT JOIN select_json_metadata sjm ON sjm.account_name = pa.account_name
                LEFT JOIN select_posting_json_metadata pjm ON pjm.account_name = pa.account_name
                JOIN hive.accounts_view av ON av.name = pa.account_name
                ON CONFLICT (account_id) DO UPDATE
                SET
                    json_metadata =
                    (
                        CASE EXCLUDED.json_metadata
                            WHEN '''' THEN hafd.%s_metadata.json_metadata
                            ELSE EXCLUDED.json_metadata
                        END
                    ),
                    posting_json_metadata =
                    (
                        CASE EXCLUDED.posting_json_metadata
                            WHEN '''' THEN hafd.%s_metadata.posting_json_metadata
                            ELSE EXCLUDED.posting_json_metadata
                        END
                    );
            END
            $$;'
        , hive.get_metadata_update_function_name( _context ), __schema, _context, _context, _context
    );
END;
$BODY$;


CREATE OR REPLACE FUNCTION hive.update_state_provider_metadata(
    _first_block hafd.blocks.num%TYPE,
    _last_block hafd.blocks.num%TYPE,
    _context hafd.context_name)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
    SET jit = OFF
AS
$BODY$
DECLARE
    __context_id hafd.contexts.id%TYPE;
BEGIN
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;
    EXECUTE format(
          'SELECT hive.%I(%s, %s);'
        , hive.get_metadata_update_function_name( _context )
        , _first_block
        , _last_block
    );
END
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_state_provider_metadata( _context hafd.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hafd.contexts.id%TYPE;
    __table_name TEXT := _context || '_metadata';
BEGIN
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'DROP TABLE hafd.%I', __table_name );
    EXECUTE format(
          'DROP FUNCTION IF EXISTS hive.%I'
        , hive.get_metadata_update_function_name( _context )
    );
END;
$BODY$
;
