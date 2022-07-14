CREATE TYPE hive.custom_operation AS (
  required_auths hive.account_name_type[],
  id int4, -- uint16_t: 2 byte, but unsigned (uint16_t)
  "data" bytea
);

SELECT _variant.create_cast_in( 'hive.custom_operation' );
SELECT _variant.create_cast_out( 'hive.custom_operation' );
