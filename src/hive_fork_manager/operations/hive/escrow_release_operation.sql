CREATE TYPE hive.escrow_release_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  agent hive.account_name_type,
  who hive.account_name_type,
  receiver hive.account_name_type,
  escrow_id int8, -- uint32_t: 4 byte, but unsigned (int8)
  hbd_amount hive.asset,
  hive_amount hive.asset
);

SELECT _variant.create_cast_in( 'hive.escrow_release_operation' );
SELECT _variant.create_cast_out( 'hive.escrow_release_operation' );
