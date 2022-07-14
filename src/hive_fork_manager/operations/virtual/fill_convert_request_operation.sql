CREATE TYPE hive.fill_convert_request_operation AS (
  "owner" hive.account_name_type,
  requestid int8, -- uint32_t: 4 bytes, but unsigned (int8)
  amount_in hive.asset,
  amount_out hive.asset
);

SELECT _variant.create_cast_in( 'hive.fill_convert_request_operation' );
SELECT _variant.create_cast_out( 'hive.fill_convert_request_operation' );
