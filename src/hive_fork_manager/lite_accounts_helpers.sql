CREATE OR REPLACE FUNCTION hive.verify_authority(IN trx hive.transaction_type, IN authority hive.authority, IN chain_id TEXT)
RETURNS BOOL AS 'MODULE_PATHNAME', 'verify_authority' LANGUAGE C;
