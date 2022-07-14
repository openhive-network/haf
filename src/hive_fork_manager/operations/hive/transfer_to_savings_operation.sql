CREATE TYPE hive.transfer_to_savings_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  amount hive.asset,
  memo hive.memo
);

SELECT _variant.create_cast_in( 'hive.transfer_to_savings_operation' );
SELECT _variant.create_cast_out( 'hive.transfer_to_savings_operation' );
