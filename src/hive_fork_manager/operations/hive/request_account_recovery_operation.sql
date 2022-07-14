CREATE TYPE hive.request_account_recovery_operation AS (
  recovery_account hive.account_name_type,
  account_to_recover hive.account_name_type,
  new_owner_authority hive.authority,
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.request_account_recovery_operation' );
SELECT _variant.create_cast_out( 'hive.request_account_recovery_operation' );
