CREATE TYPE hive.custom_binary_operation AS (
  required_owner_auths hive.account_name_type[],
  required_active_auths hive.account_name_type[],
  required_posting_auths hive.account_name_type[],
  required_auths hive.authority[],
  id hive.custom_id_type,
  "data" bytea
);

SELECT _variant.create_cast_in( 'hive.custom_binary_operation' );
SELECT _variant.create_cast_out( 'hive.custom_binary_operation' );
