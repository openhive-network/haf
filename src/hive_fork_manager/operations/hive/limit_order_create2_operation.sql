CREATE TYPE hive.limit_order_create2_operation AS (
  owner hive.account_name_type,
  orderid int8, -- uint32_t: 4 byte, but unsigned (int8)
  amount_to_sell hive.asset,
  fill_or_kill boolean,
  exchange_rate hive.price,
  expiration timestamp
);

SELECT _variant.create_cast_in( 'hive.limit_order_create2_operation' );
SELECT _variant.create_cast_out( 'hive.limit_order_create2_operation' );
