CREATE TYPE hive._props_witness_set_properties_operation AS (
  "first" text,
  second bytea
);

CREATE TYPE hive.witness_set_properties_operation AS (
  "owner" hive.account_name_type,
  props hive._props_witness_set_properties_operation[],
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.witness_set_properties_operation' );
SELECT _variant.create_cast_out( 'hive.witness_set_properties_operation' );
