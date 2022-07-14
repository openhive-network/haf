CREATE TYPE hive.failed_recurrent_transfer_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  amount hive.asset,
  memo hive.memo,
  consecutive_failures int2, -- uint8_t: 1 byte, but unsigned (int2)
  remaining_executions int4, -- uint16_t: 2 bytes, but unsigned (int4)
  deleted boolean
);

SELECT _variant.create_cast_in( 'hive.failed_recurrent_transfer_operation' );
SELECT _variant.create_cast_out( 'hive.failed_recurrent_transfer_operation' );
