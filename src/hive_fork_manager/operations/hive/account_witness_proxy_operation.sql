CREATE TYPE hive.account_witness_proxy_operation AS (
  account hive.account_name_type,
  proxy hive.account_name_type
);

SELECT _variant.create_cast_in( 'hive.account_witness_proxy_operation' );
SELECT _variant.create_cast_out( 'hive.account_witness_proxy_operation' );
