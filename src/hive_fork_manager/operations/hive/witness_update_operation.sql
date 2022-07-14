CREATE TYPE hive.witness_update_operation AS (
  "owner" hive.account_name_type,
  "url" hive.permlink,
  block_signing_key hive.public_key_type,
  props hive.legacy_chain_properties,
  fee hive.asset
);

SELECT _variant.create_cast_in( 'hive.witness_update_operation' );
SELECT _variant.create_cast_out( 'hive.witness_update_operation' );
