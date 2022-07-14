CREATE TYPE hive.fill_transfer_from_savings_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  amount hive.asset,
  request_id int8, -- uint32_t: 4 bytes, but unsigned (int8)
  memo hive.memo
);

SELECT _variant.create_cast_in( 'hive.fill_transfer_from_savings_operation' );
SELECT _variant.create_cast_out( 'hive.fill_transfer_from_savings_operation' );
