CREATE TYPE hive.smt_contribute_operation AS (
  control_account hive.account_name_type,
  symbol hive.asset_symbol,
  contribution_id int4, -- uint16_t: 2 bytes, but unsigned (int4)
  contribution hive.asset,
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.smt_contribute_operation' );
SELECT _variant.create_cast_out( 'hive.smt_contribute_operation' );
