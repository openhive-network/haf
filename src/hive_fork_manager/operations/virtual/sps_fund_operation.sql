CREATE TYPE hive.sps_fund_operation AS (
  fund_account hive.account_name_type,
  additional_funds hive.asset
);

SELECT _variant.create_cast_in( 'hive.sps_fund_operation' );
SELECT _variant.create_cast_out( 'hive.sps_fund_operation' );
