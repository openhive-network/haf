CREATE TYPE hive.delegate_vesting_shares_operation AS (
  delegator hive.account_name_type,
  delegatee hive.account_name_type,
  vesting_shares hive.asset
);

SELECT _variant.create_cast_in( 'hive.delegate_vesting_shares_operation' );
SELECT _variant.create_cast_out( 'hive.delegate_vesting_shares_operation' );
