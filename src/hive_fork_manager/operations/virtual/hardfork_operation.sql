CREATE TYPE hive.hardfork_operation AS (
  hardfork_id int8 -- uint32_t: 4 bytes, but unsigned (int8)
);

SELECT _variant.create_cast_in( 'hive.hardfork_operation' );
SELECT _variant.create_cast_out( 'hive.hardfork_operation' );
