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

