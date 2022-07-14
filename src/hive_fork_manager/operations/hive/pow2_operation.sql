CREATE TYPE hive.pow2_operation AS (
  work hive_pow2_work,
  new_owner_key hive.public_key_type,
  props hive.legacy_chain_properties
);

SELECT _variant.create_cast_in( 'hive.pow2_operation' );
SELECT _variant.create_cast_out( 'hive.pow2_operation' );
