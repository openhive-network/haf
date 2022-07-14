CREATE TYPE hive.fill_order_operation AS (
  current_owner hive.account_name_type,
  current_orderid int8, -- uint32_t: 4 bytes, but unsigned (int8)
  current_pays hive.asset,
  open_owner hive.account_name_type,
  open_orderid int8, -- uint32_t: 4 bytes, but unsigned (int8)
  open_pays hive.asset
);

SELECT _variant.create_cast_in( 'hive.fill_order_operation' );
SELECT _variant.create_cast_out( 'hive.fill_order_operation' );
