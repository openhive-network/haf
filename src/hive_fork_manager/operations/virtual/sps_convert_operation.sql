CREATE TYPE hive.sps_convert_operation AS (
  fund_account hive.account_name_type,
  hive_amount_in hive.asset,
  hive_amount_out hive.asset
);

SELECT _variant.create_cast_in( 'hive.sps_convert_operation' );
SELECT _variant.create_cast_out( 'hive.sps_convert_operation' );
