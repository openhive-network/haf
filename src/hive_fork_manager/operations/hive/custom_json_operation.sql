CREATE TYPE hive.custom_json_operation AS (
  required_auths hive.account_name_type[],
  required_posting_auths hive.account_name_type[],
  id hive.custom_id_type,
  "json" text
);

SELECT _variant.create_cast_in( 'hive.custom_json_operation' );
SELECT _variant.create_cast_out( 'hive.custom_json_operation' );
