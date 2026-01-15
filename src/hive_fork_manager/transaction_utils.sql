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
