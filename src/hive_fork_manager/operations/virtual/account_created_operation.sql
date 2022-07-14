CREATE TYPE hive.account_created_operation AS (
  new_account_name hive.account_name_type,
  creator hive.account_name_type,
  initial_vesting_shares hive.asset,
  initial_delegation hive.asset
);

SELECT _variant.create_cast_in( 'hive.account_created_operation' );
SELECT _variant.create_cast_out( 'hive.account_created_operation' );
