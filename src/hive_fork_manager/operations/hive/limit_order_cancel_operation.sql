CREATE TYPE hive.limit_order_cancel_operation AS (
  "owner" hive.account_name_type,
  orderid int8 -- uint32_t: 4 byte, but unsigned (int8)
);

SELECT _variant.create_cast_in( 'hive.limit_order_cancel_operation' );
SELECT _variant.create_cast_out( 'hive.limit_order_cancel_operation' );
