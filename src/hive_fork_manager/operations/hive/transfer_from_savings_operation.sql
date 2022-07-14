CREATE TYPE hive.transfer_from_savings_operation AS (
  "from" hive.account_name_type,
  request_id int8, -- uint32_t: 4 byte, but unsigned (int8)
  "to" hive.account_name_type,
  amount hive.asset,
  memo hive.memo
);

SELECT _variant.create_cast_in( 'hive.transfer_from_savings_operation' );
SELECT _variant.create_cast_out( 'hive.transfer_from_savings_operation' );
