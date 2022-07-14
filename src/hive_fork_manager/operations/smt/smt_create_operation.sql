CREATE TYPE hive.smt_create_operation AS (
  control_account hive.account_name_type,
  symbol hive.asset_symbol,
  smt_creation_fee hive.asset,
  "precision" int2, -- uint8_t: 1 byte, but unsigned (int2)
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.smt_create_operation' );
SELECT _variant.create_cast_out( 'hive.smt_create_operation' );
