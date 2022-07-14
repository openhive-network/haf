CREATE TYPE hive.smt_set_runtime_parameters_operation AS (
  control_account hive.account_name_type,
  symbol hive.asset_symbol,
  runtime_parameters hive_smt_runtime_parameter[],
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.smt_set_runtime_parameters_operation' );
SELECT _variant.create_cast_out( 'hive.smt_set_runtime_parameters_operation' );
