-- In hive::protocol::recover_account_operation the entry recent_owner_authority is not recorded, only new_owner_authority
-- and the whole hive::protocol::request_account_recovery_operation is not recorded at all

-- updatable types
CREATE TYPE hive.keyauth_c_record_type AS
(
    account_name TEXT
    , authority_c_kind INTEGER
    , key_auth BYTEA
    , account_auth TEXT
    , weight_threshold INTEGER
    , w INTEGER
);

CREATE OR REPLACE FUNCTION hive.convert_key_type_c_int_to_enum(IN _pos integer)
    RETURNS hafd.key_type
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
DECLARE
    __arr hafd.key_type []:= enum_range(null::hafd.key_type);
BEGIN
    return __arr[_pos + 1];
END
$$;


CREATE OR REPLACE FUNCTION hive.get_keyauths(IN _operation_body hafd.operation)
    RETURNS SETOF hafd.key_type_c_int_to_enum
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN QUERY SELECT
                     account_name,
                     hive.convert_key_type_c_int_to_enum(authority_c_kind),
                     key_auth,
                     account_auth,
                     weight_threshold,
                     w
                 FROM hive.get_keyauths_wrapper(_operation_body);
END
$$;

CREATE OR REPLACE FUNCTION hive.get_genesis_keyauths()
    RETURNS SETOF hafd.key_type_c_int_to_enum
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN QUERY SELECT
                     account_name,
                     hive.convert_key_type_c_int_to_enum(authority_c_kind),
                     key_auth,
                     account_auth,
                     weight_threshold,
                     w
                 FROM hive.get_genesis_keyauths_wrapper();
END
$$;

CREATE OR REPLACE FUNCTION hive.get_hf09_keyauths()
    RETURNS SETOF hafd.key_type_c_int_to_enum
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN QUERY SELECT
                     account_name,
                     hive.convert_key_type_c_int_to_enum(authority_c_kind),
                     key_auth,
                     account_auth,
                     weight_threshold,
                     w
                 FROM hive.get_hf09_keyauths_wrapper();
END
$$;

CREATE OR REPLACE FUNCTION hive.get_hf21_keyauths()
    RETURNS SETOF hafd.key_type_c_int_to_enum
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN QUERY SELECT
                     account_name,
                     hive.convert_key_type_c_int_to_enum(authority_c_kind),
                     key_auth,
                     account_auth,
                     weight_threshold,
                     w
                 FROM hive.get_hf21_keyauths_wrapper();
END
$$;

CREATE OR REPLACE FUNCTION hive.get_hf24_keyauths()
    RETURNS SETOF hafd.key_type_c_int_to_enum
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN QUERY SELECT
                     account_name,
                     hive.convert_key_type_c_int_to_enum(authority_c_kind),
                     key_auth,
                     account_auth,
                     weight_threshold,
                     w
                 FROM hive.get_hf24_keyauths_wrapper();
END
$$;

CREATE OR REPLACE FUNCTION hive.start_provider_keyauth( _context hafd.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hafd.contexts.id%TYPE;
    __schema TEXT;
BEGIN
    __context_id = hive.get_context_id( _context );
    SELECT hc.schema INTo __schema
    FROM hafd.contexts hc
    WHERE hc.id = __context_id;

    -- all %1$s substitute _context below

    EXECUTE format($$
        DROP TABLE IF EXISTS hafd.%1$s_keyauth_a;
        DROP TABLE IF EXISTS hafd.%1$s_keyauth_k;
        $$
        , _context);

    EXECUTE format(
        $$ DROP TABLE IF EXISTS hafd.%s_accountauth
        $$
        ,_context);



-- Create keys dictionary
    EXECUTE format(
    $$
        CREATE TABLE hafd.%1$s_keyauth_k
        (
            key_id SERIAL PRIMARY KEY,
            key BYTEA UNIQUE
        );
    $$,
    _context);
-- Create Tables

    EXECUTE format($$
        CREATE TABLE hafd.%1$s_keyauth_a(
        account_id INTEGER
        , key_kind hafd.key_type
        , key_serial_id INTEGER
        , w INTEGER
        , op_serial_id  BIGINT NOT NULL
        , block_num INTEGER NOT NULL
        , timestamp TIMESTAMP NOT NULL
        , CONSTRAINT pk_%1$s_keyauth_a PRIMARY KEY  ( account_id, key_kind, key_serial_id )
        , CONSTRAINT fk_%1$s_keyauth_a_key_serial_id FOREIGN KEY (key_serial_id) REFERENCES hafd.%1$s_keyauth_k (key_id) DEFERRABLE
        );
    $$
    , _context);

    EXECUTE format($$
        CREATE TABLE hafd.%1$s_weight_threshold(
        account_id INTEGER
        , key_kind hafd.key_type
        , weight_threshold INTEGER
        , op_serial_id  BIGINT NOT NULL
        , CONSTRAINT pk_%1$s_weight_threshold PRIMARY KEY ( account_id, key_kind )
        );
    $$
    , _context);

    EXECUTE format($$
        CREATE TABLE hafd.%1$s_accountauth_a(
        account_id INTEGER
        , key_kind hafd.key_type
        , account_auth_id INTEGER
        , w INTEGER
        , op_serial_id  BIGINT NOT NULL
        , block_num INTEGER NOT NULL
        , timestamp TIMESTAMP NOT NULL
        , CONSTRAINT pk_%1$s_accountauth_a PRIMARY KEY  ( account_id, key_kind, account_auth_id )
        );
    $$
    , _context);

    EXECUTE format($$
        ALTER TABLE IF EXISTS hafd.%1$s_keyauth_a DROP CONSTRAINT IF EXISTS pk_%1$s_keyauth_a;
    $$
    , _context);

    EXECUTE format($$
        ALTER TABLE IF EXISTS hafd.%1$s_keyauth_a
            ADD CONSTRAINT pk_%1$s_keyauth_a PRIMARY KEY (key_serial_id, account_id, key_kind )
            USING INDEX TABLESPACE haf_tablespace;
    $$
    , _context);


    EXECUTE format($$
        CREATE INDEX IF NOT EXISTS idx_hive_%1$s_keyauth_a_account_id_key_kind
            ON hafd.%1$s_keyauth_a USING btree
            (account_id, key_kind)
            TABLESPACE haf_tablespace;
    $$
    , _context);

    RETURN ARRAY[format('%1$s_keyauth_a', _context), format('%1$s_keyauth_k', _context),
        format('%1$s_accountauth_a', _context), format('%1$s_weight_threshold', _context)];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.runtimecode_provider_keyauth( _context hafd.context_name )
    RETURNS VOID
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTo __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context;
    -- Persistent function definition for keyauth insertion
    -- The 'hive.start_provider_keyauth_insert_into_keyauth_a' function is created here as a permanent
    -- function rather than being dynamically generated during each call to 'hive.update_state_provider_keyauth'.

    EXECUTE format(
            $t$

        CREATE OR REPLACE FUNCTION hive.%1$s_insert_into_keyauth_a(
        _first_block integer,
        _last_block integer)
            RETURNS void
            LANGUAGE 'plpgsql'
            COST 100
            VOLATILE PARALLEL UNSAFE
            SET join_collapse_limit='16'
            SET from_collapse_limit='16'
            SET jit=false
        AS $$
        DECLARE
        __account_ae_count INT;
        __key_ae_count INT;
        __HARDFORK_9_block_num INT  := 3202773;
        __HARDFORK_21_block_num INT := 35921786;
        __HARDFORK_24_block_num INT := 47797680;
        __op_serial_id_dummy BIGINT    := 13755805291514172; -- operation with typeid=hive::protocol::hardfork_operation, old id=5036543)

        BEGIN

        -- Handles accounts that have specific (or none) keys while genesis
        -- including: 'miners', 'initminer', 'temp', 'steem', 'null'
        -- Consider relocating this logic from the current CTE to the actual 'start_provider_keyauth' execution for better efficiency.
        WITH genesis_auth_records AS MATERIALIZED
        (
            SELECT
                (SELECT a.id FROM %2$s.accounts_view a WHERE a.name = g.account_name) as account_id,
                g.account_name,
                g.key_kind,
                g.key_auth,
                NULL as account_auth,
                1 as weight_threshold,
                1 as w,
                __op_serial_id_dummy as op_serial_id,
                1 as block_num,
                (SELECT b.created_at FROM hafd.blocks b WHERE b.num = 1) as timestamp,
                1
                FROM hive.get_genesis_keyauths() as g
            WHERE  _first_block <= 1 AND 1 <= _last_block
        ),

        -- Hard fork 9 fixes some accounts that were compromised
        HARDFORK_9_fixed_auth_records AS MATERIALIZED
        (
            SELECT
            (SELECT a.id FROM %2$s.accounts_view a WHERE a.name = h.account_name) as account_id,
            *,
            __op_serial_id_dummy as op_serial_id,
            __HARDFORK_9_block_num as block_num,
            (SELECT b.created_at FROM hafd.blocks b WHERE b.num = __HARDFORK_9_block_num) as timestamp,
            hafd.operation_id( __HARDFORK_9_block_num, 60, 0xFFFFFF ) as op_stable_id
            FROM hive.get_hf09_keyauths() h
            WHERE  _first_block <= __HARDFORK_9_block_num AND __HARDFORK_9_block_num <= _last_block
        ),

        HARDFORK_21_fixed_auth_records AS MATERIALIZED
        (
            SELECT
            (SELECT a.id FROM %2$s.accounts_view a WHERE a.name = h.account_name) as account_id,
            *,
            __op_serial_id_dummy as op_serial_id,
            __HARDFORK_21_block_num as block_num,
            (SELECT b.created_at FROM hafd.blocks b WHERE b.num = __HARDFORK_21_block_num) as timestamp,
            hafd.operation_id( __HARDFORK_21_block_num, 60, 0xFFFFFF ) as op_stable_id
            FROM hive.get_hf21_keyauths() h
            WHERE  _first_block <= __HARDFORK_21_block_num AND __HARDFORK_21_block_num <= _last_block
        ),

        HARDFORK_24_fixed_auth_records AS MATERIALIZED
        (
            SELECT
            (SELECT a.id FROM %2$s.accounts_view a WHERE a.name = h.account_name) as account_id,
            *,
            __op_serial_id_dummy as op_serial_id,
            __HARDFORK_24_block_num as block_num,
            (SELECT b.created_at FROM hafd.blocks b WHERE b.num = __HARDFORK_24_block_num) as timestamp,
            hafd.operation_id( __HARDFORK_24_block_num, 60, 0xFFFFFF ) as op_stable_id
            FROM hive.get_hf24_keyauths() h
            WHERE  _first_block <= __HARDFORK_24_block_num AND __HARDFORK_24_block_num <= _last_block
        ),

        -- Handle 'pow' operation:
        -- 1. Distinguish between existing accounts and new account creation.
        -- 2. Use 'hafd.accounts' table that tracks account creation block number.
        -- 3. 'pow' initializes all keys for new accounts, but only updates 'ACTIVE' key for existing accounts.
        pow_op_type as MATERIALIZED (
            SELECT ot.id
            FROM hafd.operation_types ot
            WHERE ot.name = 'hive::protocol::pow_operation'
        ),
        pow_matching_ops as MATERIALIZED
        (
            SELECT
                    ov.body_binary,
                    ov.id,
                    ov.block_num,
                    ov.trx_in_block,
                    ov.op_pos,
                    ov.timestamp,
                    ov.op_type_id
            FROM %2$s.operations_view_extended ov
            WHERE ov.block_num BETWEEN _first_block AND _last_block  AND ov.op_type_id IN (SELECT pmot.id FROM pow_op_type pmot)
        ),
        pow_raw_auth_records AS MATERIALIZED
        (
            SELECT  (hive.get_keyauths(ov.body_binary)).*,
                    ov.id as op_serial_id,
                    ov.block_num,
                    ov.timestamp,
                    ov.id as op_stable_id
            FROM pow_matching_ops ov
        ),

        pow_min_block_per_account AS
        (
            SELECT account_name, MIN(block_num) AS pow_min_block_num
            FROM pow_raw_auth_records
            GROUP BY account_name
        ),

        pow_extended_auth_records AS materialized
        (
            SELECT (select a.id FROM %2$s.accounts_view a
            WHERE a.name = r.account_name) AS account_id,

            mb.pow_min_block_num AS pow_min_block_num,

            r.*
            FROM pow_raw_auth_records r
            LEFT JOIN pow_min_block_per_account mb ON r.account_name = mb.account_name
        ),

        -- Handle all other operations.
        matching_op_types as materialized
            (
            select ot.id from hafd.operation_types ot WHERE ot.name IN
            (
            'hive::protocol::pow2_operation',
            'hive::protocol::account_create_operation',
            'hive::protocol::account_create_with_delegation_operation',
            'hive::protocol::account_update_operation',
            'hive::protocol::account_update2_operation',
            'hive::protocol::create_claimed_account_operation',
            'hive::protocol::recover_account_operation',
            'hive::protocol::request_account_recovery_operation',
            'hive::protocol::witness_set_properties_operation',
            'hive::protocol::witness_update_operation'
            )
            ),
            matching_ops as materialized
            (
                SELECT
                        ov.body_binary,
                        ov.id,
                        ov.block_num,
                        ov.trx_in_block,
                        ov.op_pos,
                        ov.timestamp,
                        ov.op_type_id
                    FROM %2$s.operations_view_extended ov
                    WHERE ov.block_num BETWEEN _first_block AND _last_block  AND ov.op_type_id IN (SELECT mot.id FROM matching_op_types mot)
            ),
            raw_auth_records AS MATERIALIZED
            (
                SELECT
                        (hive.get_keyauths(ov.body_binary)).*,
                        ov.id as op_serial_id,
                        ov.block_num,
                        ov.timestamp,
                        ov.id as op_stable_id
                    FROM matching_ops ov
                ),
            min_block_per_pow_account AS
            (
                SELECT
                    r.account_name,
                    MIN(r.block_num) as min_block_num
                FROM
                    raw_auth_records r
                INNER JOIN
                    pow_extended_auth_records per ON r.account_name = per.account_name
                GROUP BY
                    r.account_name
            ),
            min_block_num_from_stored_table_per_account_id AS
            (
                SELECT
                    account_id,
                    MIN(block_num) AS min_block_num_from_stored_table
                FROM
                    hafd.%1$s_keyauth_a
                GROUP BY
                    account_id
            ),
            pow_extended_auth_records_with_min_block AS
            (
                SELECT
                    pow.account_id,
                    pow.account_name,
                    pow.key_kind,
                    pow.key_auth,
                    pow.account_auth,
                    pow.weight_threshold,
                    pow.w,
                    pow.op_serial_id,
                    pow.block_num,
                    pow.timestamp,
                    pow.op_stable_id,
                    mb.min_block_num,
                    pow_min_block_num,
                    mb_table.min_block_num_from_stored_table
                FROM
                    pow_extended_auth_records pow
                LEFT JOIN
                    min_block_per_pow_account mb ON pow.account_name = mb.account_name
                LEFT JOIN
                    min_block_num_from_stored_table_per_account_id mb_table ON pow.account_id = mb_table.account_id

            ),
            pow_extended_auth_records_filtered as materialized
            (
                SELECT
                    account_id,
                    account_name,
                    key_kind,
                    key_auth,
                    account_auth,
                    weight_threshold,
                    w,
                    op_serial_id,
                    block_num,
                    timestamp,
                    op_stable_id
                FROM pow_extended_auth_records_with_min_block
                WHERE LEAST(pow_min_block_num, min_block_num, min_block_num_from_stored_table) = block_num OR key_kind = 'ACTIVE'
            ),
            --Collect all paths (pow, genesis, hf9, rest)
            extended_auth_records as materialized
            (
            SELECT (select a.id FROM %2$s.accounts_view a
                where a.name = r.account_name) as account_id,
                r.*
            FROM raw_auth_records r

            UNION ALL
            SELECT
                *
            FROM
                pow_extended_auth_records_filtered

            UNION ALL
            SELECT
                account_id,
                account_name,
                key_kind,
                key_auth,
                account_auth,
                weight_threshold,
                w,
                op_serial_id,
                block_num,
                timestamp,
                op_stable_id
            FROM
                HARDFORK_9_fixed_auth_records

            UNION ALL
            SELECT
                account_id,
                account_name,
                key_kind,
                key_auth,
                account_auth,
                weight_threshold,
                w,
                op_serial_id,
                block_num,
                timestamp,
                op_stable_id
            FROM
                HARDFORK_21_fixed_auth_records

            UNION ALL
            SELECT
                account_id,
                account_name,
                key_kind,
                key_auth,
                account_auth,
                weight_threshold,
                w,
                op_serial_id,
                block_num,
                timestamp,
                op_stable_id
            FROM
                HARDFORK_24_fixed_auth_records

            UNION ALL
            SELECT *
            FROM
                genesis_auth_records
            ),
        effective_key_or_account_auth_records as materialized
        (
            WITH effective_tuple_ids as materialized 
            (
                SELECt s.account_id, s.key_kind, max(s.op_stable_id) as op_stable_id
                FROM extended_auth_records s
                GROUP BY s.account_id, s.key_kind
            )
            SELECT s1.*
            FROM extended_auth_records s1
            JOIN effective_tuple_ids e ON e.account_id = s1.account_id and e.key_kind = s1.key_kind and e.op_stable_id = s1.op_stable_id
        ),
        --- PROCESSING OF KEY BASED AUTHORITIES ---
            supplement_key_dictionary as materialized
            (
            INSERT INTO hafd.%1$s_keyauth_k as dict (key)
            SELECT DISTINCT s.key_auth
            FROM effective_key_or_account_auth_records s
            WHERE s.key_auth IS NOT NULL
            ON conflict (key) do update set key = EXCLUDED.key -- the only way to always get key-id (even it is already in dict)
            returning (xmax = 0) as is_new_key, dict.key_id, dict.key
            ),
        extended_key_auth_records as materialized
        (
            select s.*, kd.key_id
            from effective_key_or_account_auth_records s
            join supplement_key_dictionary kd on kd.key = s.key_auth
        ),
        changed_key_authorities as materialized
        (
            select distinct s.account_id as changed_account_id, s.key_kind as changed_key_kind
            from effective_key_or_account_auth_records s
        )
        ,delete_obsolete_key_auth_records as materialized (
            DELETE FROM hafd.%1$s_keyauth_a as ea
            using changed_key_authorities s
            where account_id = s.changed_account_id and key_kind = s.changed_key_kind
            RETURNING account_id as cleaned_account_id, key_kind as cleaned_key_kind, key_serial_id as cleaned_key_id
        ),
        store_key_auth_records as materialized
        (
            INSERT INTO hafd.%1$s_keyauth_a AS auth_entries
            ( account_id, key_kind, key_serial_id, w, op_serial_id, block_num, timestamp )
            SELECT s.account_id, s.key_kind, s.key_id, s.w, s.op_serial_id, s.block_num, s.timestamp
            FROM extended_key_auth_records s
        --		LEFT JOIN delete_obsolete_key_auth_records d ON d.cleaned_account_id = s.account_id and d.cleaned_key_kind = s.key_kind
            ON CONFLICT ON CONSTRAINT pk_%1$s_keyauth_a DO UPDATE SET
            key_serial_id = EXCLUDED.key_serial_id,
            w =                   EXCLUDED.w,
            op_serial_id =        EXCLUDED.op_serial_id,
            block_num =           EXCLUDED.block_num,
            timestamp =           EXCLUDED.timestamp
            RETURNING (xmax = 0) as is_new_entry, auth_entries.account_id, auth_entries.key_kind, auth_entries.key_serial_id as cleaned_key_id
        )
        ,delete_obsolete_keys_from_dict as
        (
            delete from hafd.%1$s_keyauth_k as dict
            where dict.key_id in (select /*distinct*/ s.cleaned_key_id from store_key_auth_records s)
        ),
        --- PROCESSING OF ACCOUNT BASED AUTHORITIES ---
            extended_account_auth_records as MATERIALIZED
        (
            SELECT ds.*
            FROM (
            SELECT (select a.id FROM %2$s.accounts_view a
                where a.name = s.account_auth) as account_auth_id,
            s.*
            FROM effective_key_or_account_auth_records s
            ) ds
            WHERE ds.account_auth_id IS NOT NULL
        ),
        changed_account_authorities as materialized
        (
            select distinct s.account_id as changed_account_id, s.key_kind as changed_key_kind
            from effective_key_or_account_auth_records s
        ),
        delete_obsolete_account_auth_records as materialized
        (
            DELETE FROM hafd.%1$s_accountauth_a as ae
            using changed_account_authorities s
            where account_id = s.changed_account_id and key_kind = s.changed_key_kind
            RETURNING account_id as cleaned_account_id, key_kind as cleaned_key_kind, account_auth_id as cleaned_account_auth_id
        ),
        store_account_auth_records as
        (
            INSERT INTO hafd.%1$s_accountauth_a AS ae
            ( account_id, key_kind, account_auth_id, w, op_serial_id, block_num, timestamp )
            SELECT s.account_id, s.key_kind, s.account_auth_id, s.w, s.op_serial_id, s.block_num, s.timestamp
            FROM extended_account_auth_records s
            ON CONFLICT ON CONSTRAINT pk_%1$s_accountauth_a DO UPDATE SET
            account_auth_id = EXCLUDED.account_auth_id,
            w =                   EXCLUDED.w,
            op_serial_id =        EXCLUDED.op_serial_id,
            block_num =           EXCLUDED.block_num,
            timestamp =           EXCLUDED.timestamp
            RETURNING (xmax = 0) as is_new_entry, ae.account_id, ae.key_kind, ae.account_auth_id as cleaned_account_auth_id
        ),
        changed_weight_thresholds as
        (
            SELECT DISTINCT s.account_id, s.key_kind, s.weight_threshold, s.op_serial_id
            from effective_key_or_account_auth_records s
        ),
        store_weight_threshold_records as
        (
            INSERT INTO hafd.%1$s_weight_threshold AS ae
            ( account_id, key_kind, weight_threshold, op_serial_id)
            SELECT s.account_id, s.key_kind, s.weight_threshold, s.op_serial_id
            FROM changed_weight_thresholds s
            ON CONFLICT ON CONSTRAINT pk_%1$s_weight_threshold DO UPDATE SET
            weight_threshold =    EXCLUDED.weight_threshold,
            op_serial_id =        EXCLUDED.op_serial_id
            RETURNING (xmax = 0) as is_new_entry, ae.account_id, ae.key_kind, ae.weight_threshold
        )

        SELECT
        (
            select count(*) FROM
            store_account_auth_records
        ) as account_based_authority_entries,
            (select count(*) FROM store_key_auth_records) AS key_based_authority_entries
        into __account_ae_count, __key_ae_count;


        END;
        $$;
    $t$
        , _context, __schema);
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.update_state_provider_keyauth(
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
    __template TEXT;
BEGIN

    __context_id = hive.get_context_id( _context );

    __template = $t$ SELECT hive.%1$s_insert_into_keyauth_a(%L, %L) $t$;

    EXECUTE format(__template, _context, _first_block, _last_block);

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_state_provider_keyauth( _context hafd.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hafd.contexts.id%TYPE;
BEGIN
    __context_id = hive.get_context_id( _context );

    EXECUTE format($$
        DROP TABLE hafd.%1$s_keyauth_a;
        DROP TABLE hafd.%1$s_keyauth_k;
        DROP TABLE hafd.%1$s_accountauth_a;
        DROP TABLE hafd.%1$s_weight_threshold;
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


