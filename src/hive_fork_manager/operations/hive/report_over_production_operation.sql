CREATE TYPE hive.report_over_production_operation AS (
  reporter hive.account_name_type,
  first_block hive.signed_block_header,
  signed_block_header hive.signed_block_header
);

SELECT _variant.create_cast_in( 'hive.report_over_production_operation' );
SELECT _variant.create_cast_out( 'hive.report_over_production_operation' );
