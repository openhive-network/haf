CREATE TYPE hive.transfer_to_vesting_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  amount hive.asset
);

SELECT _variant.create_cast_in( 'hive.transfer_to_vesting_operation' );
SELECT _variant.create_cast_out( 'hive.transfer_to_vesting_operation' );
