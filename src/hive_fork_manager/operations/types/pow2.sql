CREATE TYPE hive.pow2_input AS (
  worker_account hive.account_name_type,
  prev_block hive.block_id_type,
  nonce NUMERIC
);

CREATE TYPE hive.pow2 AS (
  input hive.pow2_input,
  pow_summary int8 -- uint32_t: 4 byte, but unsigned (int8)
);
SELECT _variant.create_cast_in( 'hive.pow2' );
SELECT _variant.create_cast_out( 'hive.pow2' );

CREATE TYPE hive.pow2_proof AS (
  n int8, -- uint32_t: 4 byte, bute unsigned (int8)
  k int8, -- uint32_t: 4 byte, bute unsigned (int8)
  seed bytea,
  inputs int8[] -- uint32_t: 4 byte, bute unsigned (int8)
);

CREATE TYPE hive.equihash_pow AS (
  input hive.pow2_input,
  proof hive.pow2_proof,
  prev_block hive.block_id_type,
  pow_summary int8 -- uint32_t: 4 byte, but unsigned (int8)
);
SELECT _variant.create_cast_in( 'hive.equihash_pow' );
SELECT _variant.create_cast_out( 'hive.equihash_pow' );

-- TODO: Move to hive schema
CREATE DOMAIN hive_pow2_work AS variant.variant;
SELECT variant.register('hive_pow2_work', '{
  hive.pow2,
  hive.equihash_pow
}');
