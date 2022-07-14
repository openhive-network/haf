CREATE TYPE hive.return_vesting_delegation_operation AS (
  account hive.account_name_type,
  vesting_shares hive.asset
);

SELECT _variant.create_cast_in( 'hive.return_vesting_delegation_operation' );
SELECT _variant.create_cast_out( 'hive.return_vesting_delegation_operation' );
