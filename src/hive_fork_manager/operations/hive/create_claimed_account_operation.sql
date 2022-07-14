CREATE TYPE hive.create_claimed_account_operation AS (
  creator hive.account_name_type,
  new_account_name hive.account_name_type,
  "owner" hive.authority,
  active hive.authority,
  posting hive.authority,
  memo_key hive.public_key_type,
  json_metadata text,
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.create_claimed_account_operation' );
SELECT _variant.create_cast_out( 'hive.create_claimed_account_operation' );
