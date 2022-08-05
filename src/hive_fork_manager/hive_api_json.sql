CREATE OR REPLACE FUNCTION hive.build_block_json(
    previous BYTEA,
    "timestamp" TIMESTAMP,
    witness VARCHAR,
    transaction_merkle_root BYTEA,
    extensions jsonb,
    witness_signature BYTEA,
    transactions hive.transaction_type[],
    block_id BYTEA,
    signing_key TEXT
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
        'transactions', transactions,
        'block_id', encode( block_id, 'hex'),
        'signing_key', signing_key
    ) INTO __result;
    RETURN __result;
END;
$BODY$
;

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
            __block.signing_key
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
        'blocks', array_agg(
            hive.build_block_json(
                gbr.previous,
                gbr.timestamp,
                gbr.witness,
                gbr.transaction_merkle_root,
                gbr.extensions,
                gbr.witness_signature,
                gbr.transactions,
                gbr.block_id,
                gbr.signing_key
            )
        )
    ) INTO __result FROM hive.get_block_range( _starting_block_num , _count ) gbr
    WHERE gbr.timestamp IS NOT NULL;
    RETURN __result;
END;
$BODY$;
