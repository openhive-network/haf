CREATE TYPE hive.shutdown_witness_operation AS (
  "owner" hive.account_name_type
);

SELECT _variant.create_cast_in( 'hive.shutdown_witness_operation' );
SELECT _variant.create_cast_out( 'hive.shutdown_witness_operation' );
