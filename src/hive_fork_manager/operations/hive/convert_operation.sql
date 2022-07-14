CREATE TYPE hive.convert_operation AS (
  "owner" hive.account_name_type,
  requestid int8, -- uint32_t: 4 byte, bute unsigned (int8)
  amount hive.asset
);

SELECT _variant.create_cast_in( 'hive.convert_operation' );
SELECT _variant.create_cast_out( 'hive.convert_operation' );
