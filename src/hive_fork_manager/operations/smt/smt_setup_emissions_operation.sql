CREATE TYPE hive.smt_setup_emissions_operation AS (
  control_account hive.account_name_type,
  symbol hive.asset_symbol,
  schedule_time timestamp,
  emissions_unit hive.smt_emissions_unit,
  interval_seconds int8, -- uint32_t: 4 bytes, but unsigned (int8)
  interval_count int8, -- uint32_t: 4 bytes, but unsigned (int8)
  lep_time timestamp,
  rep_time timestamp,
  lep_abs_amount hive.asset,
  rep_abs_amount hive.asset,
  lep_rel_amount_numerator int8, -- uint32_t: 4 bytes, but unsigned (int8)
  rep_rel_amount_numerator int8, -- uint32_t: 4 bytes, but unsigned (int8)
  rel_amount_denom_bits int2, -- uint8_t: 1 byte, but unsigned (int2)
  "remove" boolean,
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.smt_setup_emissions_operation' );
SELECT _variant.create_cast_out( 'hive.smt_setup_emissions_operation' );
