CREATE TYPE hive.clear_null_account_balance_operation AS (
  total_cleared hive.asset[]
);

SELECT _variant.create_cast_in( 'hive.clear_null_account_balance_operation' );
SELECT _variant.create_cast_out( 'hive.clear_null_account_balance_operation' );
