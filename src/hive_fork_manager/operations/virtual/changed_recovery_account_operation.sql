CREATE TYPE hive.changed_recovery_account_operation AS (
  account hive.account_name_type,
  old_recovery_account hive.account_name_type,
  new_recovery_account hive.account_name_type
);

SELECT _variant.create_cast_in( 'hive.changed_recovery_account_operation' );
SELECT _variant.create_cast_out( 'hive.changed_recovery_account_operation' );
