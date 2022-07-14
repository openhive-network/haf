CREATE TYPE hive.account_update_operation AS (
  account hive.account_name_type,
  "owner" hive.authority,
  active hive.authority,
  posting hive.authority,
  memo_key hive.public_key_type,
  json_metadata text
);

SELECT _variant.create_cast_in( 'hive.account_update_operation' );
SELECT _variant.create_cast_out( 'hive.account_update_operation' );
