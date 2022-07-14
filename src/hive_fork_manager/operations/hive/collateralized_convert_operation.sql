CREATE TYPE hive.collateralized_convert_operation AS (
  "owner" hive.account_name_type,
  requestid int8, -- uint32_t: 4 byte, but unsigned (int8)
  amount hive.asset
);

SELECT _variant.create_cast_in( 'hive.collateralized_convert_operation' );
SELECT _variant.create_cast_out( 'hive.collateralized_convert_operation' );
