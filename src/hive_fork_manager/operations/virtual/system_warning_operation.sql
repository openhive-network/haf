CREATE TYPE hive.system_warning_operation AS (
  "message" text
);

SELECT _variant.create_cast_in( 'hive.system_warning_operation' );
SELECT _variant.create_cast_out( 'hive.system_warning_operation' );
