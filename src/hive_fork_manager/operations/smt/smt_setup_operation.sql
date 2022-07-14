CREATE TYPE hive.smt_setup_operation AS (
  control_account hive.account_name_type,
  symbol hive.asset_symbol,
  max_supply NUMERIC,
  initial_generation_policy hive_smt_generation_policy,
  contribution_begin_time timestamp,
  contribution_end_time timestamp,
  launch_time timestamp,
  hive_units_soft_cap hive.share_type,
  hive_units_hard_cap hive.share_type,
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.smt_setup_operation' );
SELECT _variant.create_cast_out( 'hive.smt_setup_operation' );
