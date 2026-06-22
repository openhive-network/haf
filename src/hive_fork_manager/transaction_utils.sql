CREATE OR REPLACE FUNCTION hive.transaction_sig_digest(
  IN _transaction JSONB,
  IN _chain_id TEXT DEFAULT NULL
)
RETURNS BYTEA
AS 'MODULE_PATHNAME', 'transaction_sig_digest' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.pubkey_from_signature(
  IN _signature BYTEA,
  IN _digest BYTEA
)
RETURNS TEXT
AS 'MODULE_PATHNAME', 'pubkey_from_signature' LANGUAGE C;

-- Second-layer (L2) transaction signing digest:
--   sha256( chain_id || JCS(_signed_fields) )
-- where JCS is RFC-8785 canonical JSON and _signed_fields is the object
-- {app, version, operations, expiration, nonce?} (without signatures). Numbers in
-- the signed body must be integers within +-(2^53-1); larger/decimal values must
-- be carried as strings. _chain_id is a hex chain id; defaults to HIVE_CHAIN_ID.
CREATE OR REPLACE FUNCTION hive.l2_transaction_digest(
  IN _signed_fields JSONB,
  IN _chain_id TEXT DEFAULT NULL
)
RETURNS BYTEA
AS 'MODULE_PATHNAME', 'l2_transaction_digest' LANGUAGE C;

-- Convert a base58 STM public key string to its 33-byte compressed binary form
-- (inverse of hive.public_key_to_string); STRICT so NULL in -> NULL out.
CREATE OR REPLACE FUNCTION hive.l2_pubkey_to_bytea(
  IN _public_key TEXT
)
RETURNS BYTEA
AS 'MODULE_PATHNAME', 'l2_pubkey_to_bytea' LANGUAGE C STRICT;
