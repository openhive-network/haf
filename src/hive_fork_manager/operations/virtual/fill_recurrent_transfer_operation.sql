CREATE TYPE hive.fill_recurrent_transfer_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  amount hive.asset,
  memo hive.memo,
  remaining_executions int4 -- uint16_t: 2 bytes, but unsigned (int4)
);

SELECT _variant.create_cast_in( 'hive.fill_recurrent_transfer_operation' );
SELECT _variant.create_cast_out( 'hive.fill_recurrent_transfer_operation' );
