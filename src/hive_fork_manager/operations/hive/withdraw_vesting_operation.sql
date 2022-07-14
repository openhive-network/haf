CREATE TYPE hive.withdraw_vesting_operation AS (
  "to" hive.account_name_type,
  vesting_shares hive.asset
);

SELECT _variant.create_cast_in( 'hive.withdraw_vesting_operation' );
SELECT _variant.create_cast_out( 'hive.withdraw_vesting_operation' );
