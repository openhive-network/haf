CREATE TYPE hive.pow_operation AS (
  worker_account hive.account_name_type,
  block_id hive.block_id_type,
  nonce NUMERIC,
  work hive.pow,
  props hive.legacy_chain_properties
);

SELECT _variant.create_cast_in( 'hive.pow_operation' );
SELECT _variant.create_cast_out( 'hive.pow_operation' );
