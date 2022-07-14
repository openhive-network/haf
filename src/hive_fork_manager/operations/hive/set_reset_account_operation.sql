CREATE TYPE hive.set_reset_account_operation AS (
  account hive.account_name_type,
  current_reset_account hive.account_name_type,
  reset_account hive.account_name_type
);

SELECT _variant.create_cast_in( 'hive.set_reset_account_operation' );
SELECT _variant.create_cast_out( 'hive.set_reset_account_operation' );
