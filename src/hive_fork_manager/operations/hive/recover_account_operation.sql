CREATE TYPE hive.recover_account_operation AS (
  account_to_recover hive.account_name_type,
  new_owner_authority hive.authority,
  recent_owner_authority hive.authority,
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.recover_account_operation' );
SELECT _variant.create_cast_out( 'hive.recover_account_operation' );
