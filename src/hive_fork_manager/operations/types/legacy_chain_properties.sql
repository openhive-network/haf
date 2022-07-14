CREATE TYPE hive.legacy_chain_properties AS (
  account_creation_fee hive.legacy_hive_asset,
  maximum_block_size int8, -- uint32_t: 4 byte, but unsigned (int8)
  hbd_interest_rate int4 -- uint16_t: 2 byte, but unsigned (int4)
);
