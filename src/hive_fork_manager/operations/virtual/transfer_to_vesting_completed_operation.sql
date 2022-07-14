CREATE TYPE hive.transfer_to_vesting_completed_operation AS (
  from_account hive.account_name_type,
  to_account hive.account_name_type,
  hive_vested hive.asset,
  vesting_shares_received hive.asset
);

SELECT _variant.create_cast_in( 'hive.transfer_to_vesting_completed_operation' );
SELECT _variant.create_cast_out( 'hive.transfer_to_vesting_completed_operation' );
