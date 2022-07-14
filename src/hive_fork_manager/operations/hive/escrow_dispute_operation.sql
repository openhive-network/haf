CREATE TYPE hive.escrow_dispute_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  agent hive.account_name_type,
  who hive.account_name_type,
  escrow_id int8 -- uint32_t: 4 byte, but unsigned (int8)
);

SELECT _variant.create_cast_in( 'hive.escrow_dispute_operation' );
SELECT _variant.create_cast_out( 'hive.escrow_dispute_operation' );
