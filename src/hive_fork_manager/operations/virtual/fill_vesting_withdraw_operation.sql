CREATE TYPE hive.fill_vesting_withdraw_operation AS (
  from_account hive.account_name_type,
  to_account hive.account_name_type,
  withdrawn hive.asset,
  deposited hive.asset
);

SELECT _variant.create_cast_in( 'hive.fill_vesting_withdraw_operation' );
SELECT _variant.create_cast_out( 'hive.fill_vesting_withdraw_operation' );
