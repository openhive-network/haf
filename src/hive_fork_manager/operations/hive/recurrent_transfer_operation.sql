CREATE TYPE hive.recurrent_transfer_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  amount hive.asset,
  memo hive.memo,
  recurrence int4, -- uint16_t: 2 byte, but unsigned (int4)
  executions int4, -- uint16_t: 2 byte, but unsigned (int4)
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.recurrent_transfer_operation' );
SELECT _variant.create_cast_out( 'hive.recurrent_transfer_operation' );
