CREATE TYPE hive.cancel_transfer_from_savings_operation AS (
  "from" hive.account_name_type,
  request_id int8 -- uint32_t: 4 byte, but unsigned (int8)
);

SELECT _variant.create_cast_in( 'hive.cancel_transfer_from_savings_operation' );
SELECT _variant.create_cast_out( 'hive.cancel_transfer_from_savings_operation' );
