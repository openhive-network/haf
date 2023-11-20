-- In hive::protocol::recover_account_operation the entry recent_owner_authority is not recorded, only new_owner_authority
-- and the whole hive::protocol::request_account_recovery_operation is not recorded at all

CREATE OR REPLACE FUNCTION hive.print_json_with_label(label text, json_result json) RETURNS INTEGER LANGUAGE plpgsql AS $p$
BEGIN
    RAISE NOTICE E'% >>>> \n%', label, json_result;
    RETURN 1;
END;
$p$;


CREATE OR REPLACE FUNCTION hive.start_provider_keyauth( _context hive.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
BEGIN

    __context_id = hive.get_context_id( _context );

    -- all %1$s substitute _context below

    EXECUTE format($$
        DROP TABLE IF EXISTS hive.%1$s_keyauth_a;
        DROP TABLE IF EXISTS hive.%1$s_keyauth_k;
        $$
        , _context);

    EXECUTE format(
        $$ DROP TABLE IF EXISTS hive.%s_accountauth
        $$
        ,_context);



-- Create keys dictionary
    EXECUTE format(
    $$
        CREATE TABLE hive.%1$s_keyauth_k
        (
            key_id SERIAL PRIMARY KEY,
            key BYTEA UNIQUE
        );
    $$,
    _context);
-- Create Tables

    EXECUTE format($$
        CREATE TABLE hive.%1$s_keyauth_a(
        account_id INTEGER
        , key_kind hive.key_type
        , key_serial_id INTEGER
        , weight_threshold INTEGER
        , w INTEGER
        , op_serial_id  BIGINT NOT NULL
        , block_num INTEGER NOT NULL
        , timestamp TIMESTAMP NOT NULL
        , CONSTRAINT pk_%1$s_keyauth_a PRIMARY KEY  ( account_id, key_kind, key_serial_id )
        , CONSTRAINT fk_%1$s_keyauth_a_key_serial_id FOREIGN KEY (key_serial_id) REFERENCES hive.%1$s_keyauth_k (key_id) DEFERRABLE
        );
    $$
    , _context);




    EXECUTE format($$
        CREATE TABLE hive.%1$s_accountauth_a(
        account_id INTEGER
        , key_kind hive.key_type
        , account_auth_id INTEGER
        , weight_threshold INTEGER
        , w INTEGER
        , op_serial_id  BIGINT NOT NULL
        , block_num INTEGER NOT NULL
        , timestamp TIMESTAMP NOT NULL
        , CONSTRAINT pk_%1$s_accountauth_a PRIMARY KEY  ( account_id, key_kind, account_auth_id )
        );
    $$
    , _context);


    -- Persistent function definition for keyauth insertion
    -- The 'hive.start_provider_keyauth_insert_into_keyauth_a' function is created here as a permanent
    -- function rather than being dynamically generated during each call to 'hive.update_state_provider_keyauth'.

    EXECUTE format(
    $t$
    CREATE OR REPLACE FUNCTION hive.%1$s_insert_into_keyauth_a(
        _first_block hive.blocks.num%%TYPE,
        _last_block hive.blocks.num%%TYPE
    ) RETURNS VOID AS $$
    BEGIN

        -- This is the initial CTE which selects key authority-related data from an operations view,
        -- filtering by block numbers and specific operation types related to account creation and updating.
        WITH temp_keyauths AS MATERIALIZED(
            SELECT
                (hive.get_keyauths(ov.body_binary)).*,
                ov.id as op_serial_id,
                block_num,
                timestamp,
                ov.op_type_id,
                hive.calculate_operation_stable_id(block_num, trx_in_block, op_pos) as op_stable_id
            FROM hive.%1$s_operations_view ov
            JOIN hive.operation_types ot ON ov.op_type_id = ot.id
            WHERE ov.block_num BETWEEN _first_block AND _last_block
            AND ot.name IN (
                'hive::protocol::pow_operation',
                'hive::protocol::account_create_operation',
                'hive::protocol::account_create_with_delegation_operation',
                'hive::protocol::account_update_operation',
                'hive::protocol::account_update2_operation',
                'hive::protocol::create_claimed_account_operation',
                'hive::protocol::recover_account_operation',
                'hive::protocol::request_account_recovery_operation',
                'hive::protocol::witness_set_properties_operation'
            )
        ),

        /* 
            ======================================
            == BEGIN: ACCOUNT AUTHORIZATIONS ==
            ======================================
        */

        -- Filters the results from temp_keyauths where the key_auth is null to handle account authorizations separately.
        keyauths_output_null AS (
            SELECT *
            FROM temp_keyauths
            WHERE key_auth IS NULL
        ),

        -- Groups results by account_name and key_kind to select the latest operation for each account and key type.
        max_op_serial_dictionary_accountauth AS (
            SELECT account_name, key_kind, MAX(op_stable_id) as max_op_stable_id
            FROM keyauths_output_null
            GROUP BY account_name, key_kind
        ),

        -- Joins the latest operations data with account identifiers, adding account_id.
        combined_data_accountauths AS (
            SELECT derived.*
                , accounts_view.id as_account_id
                , av.id as account_supervisor_id
            FROM (
                SELECT keyauths_output_null.*
                FROM keyauths_output_null
                JOIN max_op_serial_dictionary_accountauth dict ON keyauths_output_null.account_name = dict.account_name 
                                                            AND keyauths_output_null.key_kind = dict.key_kind 
                                                            AND keyauths_output_null.op_stable_id = dict.max_op_stable_id
            ) AS derived
            JOIN hive.%1$s_accounts_view accounts_view ON accounts_view.name = derived.account_name
            JOIN hive.%1$s_accounts_view av ON av.name = derived.account_auth
        ),

        -- Finally inserts updated account authorization data into the accountauth_a table.
        inserted_accountauths AS (
            INSERT INTO hive.%1$s_accountauth_a
            SELECT
                as_account_id,
                key_kind,
                account_supervisor_id,
                weight_threshold,
                w,
                op_serial_id,
                block_num,
                timestamp
            FROM combined_data_accountauths
            ON CONFLICT ON CONSTRAINT pk_%1$s_accountauth_a
            DO UPDATE SET
                 account_id =           EXCLUDED.account_id
                , key_kind =            EXCLUDED.key_kind
                , account_auth_id =     EXCLUDED.account_auth_id
                , weight_threshold =    EXCLUDED.weight_threshold
                , w =                   EXCLUDED.w
                , op_serial_id  =       EXCLUDED.op_serial_id
                , block_num =           EXCLUDED.block_num
                , timestamp =           EXCLUDED.timestamp
            RETURNING * -- for dump only
        ),

        /* 
            ======================================
            == END: ACCOUNT AUTHORIZATIONS ==
            ======================================
        */

        /* 
            ======================================
            == START: KEY AUTHORIZATIONS ==
            ======================================
        */

        -- Filters out non-null key_auth entries for processing key authorizations.
        keyauths_output AS (
            SELECT *
            FROM temp_keyauths
            WHERE key_auth IS NOT NULL
        ),

        -- Identifies the latest operation for each account and key type by the maximum op_serial_id.
        max_op_serial_dictionary AS (
            SELECT account_name, key_kind, MAX(op_stable_id) as max_op_stable_id
            FROM keyauths_output
            GROUP BY account_name, key_kind
        ),

        -- Prepares joined data of latest operations with account identifiers for key authorization entries.
        combined_data AS (
            SELECT derived.*,
                accounts_view.id as_account_id
            FROM (
                SELECT keyauths_output.*
                FROM keyauths_output
                JOIN max_op_serial_dictionary dict ON keyauths_output.account_name = dict.account_name 
                                                AND keyauths_output.key_kind = dict.key_kind 
                                                AND keyauths_output.op_stable_id = dict.max_op_stable_id
            ) AS derived
            JOIN hive.%1$s_accounts_view accounts_view ON accounts_view.name = derived.account_name
        ),

        -- Inserts new unique public keys into the keyauth_k dictionary table.
        inserted_data AS (
            INSERT INTO hive.%1$s_keyauth_k (key)
            SELECT DISTINCT key_auth FROM combined_data
            ON CONFLICT DO NOTHING
            RETURNING key, key_id
        ),

        -- Deletes existing keyauth_a records to be replaced with updated data.
        deleted_keyauths AS (
            DELETE FROM hive.%1$s_keyauth_a
            WHERE (account_id, key_kind) IN (SELECT account_id, key_kind FROM combined_data)
            RETURNING * -- for dump only
        )

        ,
        dump_combined AS (
        SELECT 
            1 AS num,
             ARRAY[
                    hive.print_json_with_label('mtlk combined temp_keyauths', (SELECT json_agg(t) FROM (SELECT * FROM                           temp_keyauths) t)),
                    hive.print_json_with_label('mtlk combined keyauths_output', (SELECT json_agg(t) FROM (SELECT * FROM                         keyauths_output) t)),
                    hive.print_json_with_label('mtlk combined keyauths_output_null', (SELECT json_agg(t) FROM (SELECT * FROM                    keyauths_output_null) t)),
                    hive.print_json_with_label('mtlk combined max_op_serial_dictionary_accountauth', (SELECT json_agg(t) FROM (SELECT * FROM    max_op_serial_dictionary_accountauth) t)),
                    hive.print_json_with_label('mtlk combined combined_data_accountauths', (SELECT json_agg(t) FROM (SELECT * FROM              combined_data_accountauths) t)),
                    --hive.print_json_with_label('mtlk combined deleted_account_auths', (SELECT json_agg(t) FROM (SELECT * FROM                   deleted_account_auths) t)),
                    hive.print_json_with_label('mtlk combined inserted_accountauths', (SELECT json_agg(t) FROM (SELECT * FROM                   inserted_accountauths) t)),
                    hive.print_json_with_label('mtlk combined max_op_serial_dictionary', (SELECT json_agg(t) FROM (SELECT * FROM                max_op_serial_dictionary) t)),
                    hive.print_json_with_label('mtlk combined combined_data', (SELECT json_agg(t) FROM (SELECT * FROM                           combined_data) t)),
                    hive.print_json_with_label('mtlk combined inserted_data', (SELECT json_agg(t) FROM (SELECT * FROM                           inserted_data) t)),
                    hive.print_json_with_label('mtlk combined deleted_keyauths', (SELECT json_agg(t) FROM (SELECT * FROM                        deleted_keyauths) t))

                ] AS dump_results
         )
 

        -- Finally, fills the keyauths table
        INSERT INTO hive.%1$s_keyauth_a
        SELECT
            as_account_id,
            key_kind,
            key_id,
            weight_threshold,
            w,
            op_serial_id,
            block_num,
            timestamp
        FROM combined_data
        JOIN inserted_data ON combined_data.key_auth = inserted_data.key
                LEFT JOIN dump_combined ON dump_combined.num = combined_data.block_num
        ;

        /* 
            ======================================
            == END: KEY AUTHORIZATIONS ==
            ======================================
        */

        END;
    $$ LANGUAGE plpgsql;
    $t$
    , _context);


    RETURN ARRAY[format('%1$s_keyauth_a', _context), format('%1$s_keyauth_k', _context), format('%1$s_accountauth_a', _context)];
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
    __template TEXT;
BEGIN

    __context_id = hive.get_context_id( _context );

    __template = $t$ SELECT hive.%1$s_insert_into_keyauth_a(%L, %L) $t$;

    EXECUTE format(__template, _context, _first_block, _last_block);

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
BEGIN
    __context_id = hive.get_context_id( _context );

    EXECUTE format($$
        DROP TABLE hive.%1$s_keyauth_a;
        DROP TABLE hive.%1$s_keyauth_k;
        DROP TABLE hive.%1$s_accountauth_a;
        $$
        , _context);

    EXECUTE format(
        $$
            DROP FUNCTION IF EXISTS hive.%1$s_insert_into_keyauth_a
        $$
        , _context);

END;
$BODY$
;


