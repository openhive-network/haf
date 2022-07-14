CREATE TYPE hive.reset_account_operation AS (
  reset_account hive.account_name_type,
  account_to_reset hive.account_name_type,
  new_owner_authority hive.authority
);

SELECT _variant.create_cast_in( 'hive.reset_account_operation' );
SELECT _variant.create_cast_out( 'hive.reset_account_operation' );
