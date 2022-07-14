CREATE TYPE hive.vesting_shares_split_operation AS (
  "owner" hive.account_name_type,
  vesting_shares_before_split hive.asset,
  vesting_shares_after_split hive.asset
);

SELECT _variant.create_cast_in( 'hive.vesting_shares_split_operation' );
SELECT _variant.create_cast_out( 'hive.vesting_shares_split_operation' );
