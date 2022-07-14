CREATE TYPE hive.limit_order_cancelled_operation AS (
  seller hive.account_name_type,
  orderid int4, -- uint16_t: 2 bytes, but unsigned (int4)
  amount_back hive.asset
);

SELECT _variant.create_cast_in( 'hive.limit_order_cancelled_operation' );
SELECT _variant.create_cast_out( 'hive.limit_order_cancelled_operation' );
