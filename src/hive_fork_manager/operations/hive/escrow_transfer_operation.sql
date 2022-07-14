CREATE TYPE hive.escrow_transfer_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  agent hive.account_name_type,
  escrow_id int8, -- uint32_t: 4 byte, but unsigned (int8)
  hbd_amount hive.asset,
  hive_amount hive.asset,
  fee hive.asset,
  ratification_deadline timestamp,
  escrow_expiration timestamp,
  json_meta text
);

SELECT _variant.create_cast_in( 'hive.escrow_transfer_operation' );
SELECT _variant.create_cast_out( 'hive.escrow_transfer_operation' );
