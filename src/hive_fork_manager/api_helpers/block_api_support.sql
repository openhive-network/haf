-- ##########################################
-- ############### DATA TYPES ###############
-- ##########################################

DROP TYPE IF EXISTS hive.block_header_type CASCADE;
CREATE TYPE hive.block_header_type AS (
      previous bytea
    , timestamp TIMESTAMP WITHOUT TIME ZONE
    , witness VARCHAR(16)
    , transaction_merkle_root bytea
    , extensions jsonb
    , witness_signature bytea
    );

DROP TYPE IF EXISTS hive.transaction_type CASCADE;
CREATE TYPE hive.transaction_type AS (
      ref_block_num integer
    , ref_block_prefix bigint
    , expiration TIMESTAMP WITHOUT TIME ZONE
    , operations hive.operation[]
    , extensions jsonb
    , signatures bytea[]
    );

DROP TYPE IF EXISTS hive.block_type CASCADE;
CREATE TYPE hive.block_type AS (
      previous bytea
    , timestamp TIMESTAMP WITHOUT TIME ZONE
    , witness VARCHAR(16)
    , transaction_merkle_root bytea
    , extensions jsonb
    , witness_signature bytea
    , transactions hive.transaction_type[]
    , block_id bytea
    , signing_key text
    , transaction_ids bytea[]
    );

DROP TYPE IF EXISTS hive.block_type_ext CASCADE;
CREATE TYPE hive.block_type_ext AS (
    block_num INTEGER,
    block hive.block_type
);

-- ##########################################
-- ############ HELPER FUNCTIONS ############
-- ##########################################

CREATE OR REPLACE FUNCTION hive.get_block_from_views( _block_num_start INT, _block_count INT )
    RETURNS SETOF hive.block_type_ext
    LANGUAGE plpgsql
    VOLATILE
    SET JIT=FALSE
AS
$BODY$
BEGIN

        RETURN QUERY
        WITH
        -- hive.get_block_from_views
        base_blocks_data AS MATERIALIZED (
            SELECT
                hb.num,
                hb.prev,
                hb.created_at,
                hb.transaction_merkle_root,
                hb.witness_signature,
                COALESCE(hb.extensions,  array_to_json(ARRAY[] :: INT[]) :: JSONB) AS extensions,
                hb.producer_account_id,
                hb.hash,
                hb.signing_key,
                ha.name
            FROM hive.blocks_view hb
            JOIN hive.accounts_view ha ON hb.producer_account_id = ha.id
            WHERE hb.num BETWEEN _block_num_start AND ( _block_num_start + _block_count - 1 )
            ORDER BY hb.num ASC
        ),
        trx_details AS MATERIALIZED (
            SELECT
                htv.block_num,
                htv.trx_in_block,
                htv.expiration,
                htv.ref_block_num,
                htv.ref_block_prefix,
                htv.trx_hash,
                htv.signature
            FROM hive.transactions_view htv
            WHERE htv.block_num BETWEEN _block_num_start AND ( _block_num_start + _block_count - 1 )
            ORDER BY htv.block_num ASC, htv.trx_in_block ASC
        ),
        operations AS (
                SELECT ho.block_num, ho.trx_in_block, ARRAY_AGG(ho.body_binary ORDER BY op_pos ASC) bodies
                FROM hive.operations_view ho
                WHERE
                    ho.op_type_id <= (SELECT ot.id FROM hive.operation_types ot WHERE ot.is_virtual = FALSE ORDER BY ot.id DESC LIMIT 1)
                    AND ho.block_num BETWEEN _block_num_start AND ( _block_num_start + _block_count - 1 )
                GROUP BY ho.block_num, ho.trx_in_block
                ORDER BY ho.block_num ASC, trx_in_block ASC
        ),
        full_transactions_with_signatures AS MATERIALIZED (
                SELECT
                    htv.block_num,
                    ARRAY_AGG(htv.trx_hash ORDER BY htv.trx_in_block ASC) AS trx_hashes,
                    ARRAY_AGG(
                        (
                            htv.ref_block_num,
                            htv.ref_block_prefix,
                            htv.expiration,
                            ops.bodies,
                            array_to_json(ARRAY[] :: INT[]) :: JSONB,
                            (
                                CASE
                                    WHEN multisigs.signatures = ARRAY[NULL]::BYTEA[] THEN ARRAY[ htv.signature ]::BYTEA[]
                                    ELSE htv.signature || multisigs.signatures
                                END
                            )
                        ) :: hive.transaction_type
                        ORDER BY htv.trx_in_block ASC
                    ) AS transactions
                FROM
                (
                    SELECT txd.trx_hash, ARRAY_AGG(htmv.signature) AS signatures
                    FROM trx_details txd
                    LEFT JOIN hive.transactions_multisig_view htmv
                    ON txd.trx_hash = htmv.trx_hash
                    GROUP BY txd.trx_hash
                ) AS multisigs
                JOIN trx_details htv ON htv.trx_hash = multisigs.trx_hash
                JOIN operations ops ON ops.block_num = htv.block_num AND htv.trx_in_block = ops.trx_in_block
                WHERE ops.block_num BETWEEN _block_num_start AND ( _block_num_start + _block_count - 1 )
                GROUP BY htv.block_num
                ORDER BY htv.block_num ASC
        )
        SELECT
            bbd.num,
            (
                bbd.prev,
                bbd.created_at,
                bbd.name,
                bbd.transaction_merkle_root,
                bbd.extensions,
                bbd.witness_signature,
                ftws.transactions,
                bbd.hash,
                bbd.signing_key,
                ftws.trx_hashes
            ) :: hive.block_type
        FROM base_blocks_data bbd
        LEFT JOIN full_transactions_with_signatures ftws ON ftws.block_num = bbd.num
        ORDER BY bbd.num ASC
        ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.transactions_to_json(transactions hive.transaction_type[])
    RETURNS JSONB
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __result JSONB;
BEGIN
    SELECT array_to_json(ARRAY( SELECT jsonb_build_object(
        'ref_block_num', x.ref_block_num,
        'ref_block_prefix', x.ref_block_prefix,
        'expiration', x.expiration,
        'operations', x.operations :: JSONB[],
        'extensions', COALESCE(x.extensions, jsonb_build_array()),
        'signatures', (
            CASE
                WHEN array_length(x.signatures, 1) > 0 AND x.signatures != ARRAY[ NULL ]::BYTEA[] THEN (SELECT ARRAY( SELECT encode(unnest(x.signatures), 'hex')))
                ELSE ARRAY[] :: TEXT[]
            END
        )
    )
    FROM ( SELECT (unnest(transactions)).* ) x ) ) INTO __result;
    RETURN __result;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.build_block_json(
    previous BYTEA,
    "timestamp" TIMESTAMP,
    witness VARCHAR,
    transaction_merkle_root BYTEA,
    extensions jsonb,
    witness_signature BYTEA,
    transactions hive.transaction_type[],
    block_id BYTEA,
    signing_key TEXT,
    transaction_ids BYTEA[]
)
    RETURNS JSONB
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'previous', encode( previous, 'hex'),
        'timestamp', TRIM(both '"' from to_json(timestamp)::text),
        'witness', witness,
        'transaction_merkle_root', encode( transaction_merkle_root, 'hex'),
        'extensions', COALESCE(extensions, jsonb_build_array()),
        'witness_signature', encode( witness_signature, 'hex'),
        'transactions', COALESCE(hive.transactions_to_json(transactions), jsonb_build_array()),
        'block_id', encode( block_id, 'hex'),
        'signing_key', signing_key,
        'transaction_ids', (SELECT ARRAY( SELECT encode(unnest(transaction_ids), 'hex')))
    ) INTO __result;
    RETURN __result;
END;
$BODY$
;

-- ##########################################
-- ############# DATA FUNCTIONS #############
-- ##########################################

CREATE OR REPLACE FUNCTION hive.get_block_header( _block_num INT )
    RETURNS hive.block_header_type
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __witness_account_id INTEGER;
    __result hive.block_header_type := NULL;
BEGIN
    SELECT
           hb.prev
         , hb.created_at
         , hb.transaction_merkle_root
         , hb.witness_signature
         , hb.extensions
         , hb.producer_account_id
    FROM hive.blocks_view hb
    WHERE hb.num = _block_num
    INTO
         __result.previous
       , __result.timestamp
       , __result.transaction_merkle_root
       , __result.witness_signature
       , __result.extensions
       , __witness_account_id;

    SELECT ha.name
    FROM hive.accounts_view ha
    WHERE ha.id = __witness_account_id
    INTO __result.witness;

    RETURN __result;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_block( _block_num INT )
    RETURNS hive.block_type
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    RETURN (hive.get_block_from_views( _block_num, 1 )).block;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_block_range( _starting_block_num INT, _count INT )
    RETURNS SETOF hive.block_type
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN

    IF _count = 0 OR (_starting_block_num ::BIGINT + _count - 1) > POW(2, 31) :: BIGINT THEN
        IF NOT _count <= 1000 THEN
            RAISE EXCEPTION 'Assert Exception:count <= 1000: You can only ask for 1000 blocks at a timerethrow';
        END IF;
        RETURN QUERY SELECT (NULL::hive.block_type).* LIMIT 0;
        RETURN;
    END IF;

    IF NOT _starting_block_num  > 0 THEN
        RAISE EXCEPTION 'Assert Exception:starting_block_num > 0: Invalid starting block numberrethrow';
    END IF;

    IF NOT _count > 0 THEN
        RAISE EXCEPTION 'Assert Exception:count > 0: Why ask for zero blocks?rethrow';
    END IF;

    IF NOT _count <= 1000 THEN
        RAISE EXCEPTION 'Assert Exception:count <= 1000: You can only ask for 1000 blocks at a timerethrow';
    END IF;

    RETURN QUERY SELECT (block).* FROM hive.get_block_from_views( _starting_block_num, _count );
END;
$BODY$
;

-- ##########################################
-- ###### JSON SERIALIZATION FUNCTIONS ######
-- ##########################################

CREATE OR REPLACE FUNCTION hive.get_block_json( _block_num INT )
    RETURNS JSONB
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __block hive.block_type;
    __result JSON;
BEGIN
    SELECT * FROM hive.get_block( _block_num ) INTO __block;

    IF __block.timestamp IS NULL THEN
        RETURN jsonb_build_object();
    END IF;

    SELECT jsonb_build_object(
        'block', hive.build_block_json(
            __block.previous,
            __block.timestamp,
            __block.witness,
            __block.transaction_merkle_root,
            __block.extensions,
            __block.witness_signature,
            __block.transactions,
            __block.block_id,
            __block.signing_key,
            __block.transaction_ids

        )
    ) INTO __result ;
    RETURN __result;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_block_header_json( _block_num INT )
    RETURNS JSONB
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __block hive.block_header_type;
    __result JSON;
BEGIN

    SELECT * FROM hive.get_block_header( _block_num ) INTO __block;

    IF __block.timestamp IS NULL THEN
        RETURN jsonb_build_object();
    END IF;

    SELECT jsonb_build_object(
        'header', jsonb_build_object(
            'previous', encode( __block.previous, 'hex') :: TEXT,
            'timestamp', TRIM(both '"' from to_json(__block.timestamp)::text),
            'witness', __block.witness,
            'transaction_merkle_root', encode( __block.transaction_merkle_root, 'hex'),
            'extensions', COALESCE(__block.extensions, jsonb_build_array())
        )
    ) INTO __result;
    RETURN __result;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_block_range_json( _starting_block_num INT, _count INT )
    RETURNS JSONB
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'blocks', COALESCE(array_agg(
            hive.build_block_json(
                gbr.previous,
                gbr.timestamp,
                gbr.witness,
                gbr.transaction_merkle_root,
                gbr.extensions,
                gbr.witness_signature,
                gbr.transactions,
                gbr.block_id,
                gbr.signing_key,
                gbr.transaction_ids
            )
        ), ARRAY[]::JSONB[] )
    ) INTO __result FROM hive.get_block_range( _starting_block_num , _count ) gbr
    WHERE gbr.timestamp IS NOT NULL;
    RETURN __result;
END;
$BODY$;
