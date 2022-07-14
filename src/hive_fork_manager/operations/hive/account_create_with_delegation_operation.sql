CREATE TYPE hive.account_create_with_delegation_operation AS (
  fee hive.asset,
  delegation hive.asset,
  creator hive.account_name_type,
  new_account_name hive.account_name_type,
  "owner" hive.authority,
  active hive.authority,
  posting hive.authority,
  memo_key hive.public_key_type,
  json_metadata text,
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.account_create_with_delegation_operation' );
SELECT _variant.create_cast_out( 'hive.account_create_with_delegation_operation' );
