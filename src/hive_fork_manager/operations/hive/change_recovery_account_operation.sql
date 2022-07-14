CREATE TYPE hive.change_recovery_account_operation AS (
  account_to_recover hive.account_name_type,
  new_recovery_account hive.account_name_type,
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.change_recovery_account_operation' );
SELECT _variant.create_cast_out( 'hive.change_recovery_account_operation' );
