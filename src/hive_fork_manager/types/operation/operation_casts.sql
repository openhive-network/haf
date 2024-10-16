-- SQL-side binary casts

CREATE CAST (bytea AS hive_data.operation)
  WITH FUNCTION hive_data._operation_bin_in
  AS IMPLICIT;

CREATE CAST (hive_data.operation AS bytea)
  WITH FUNCTION hive_data._operation_bin_out
  AS IMPLICIT;

CREATE CAST (hive_data.operation AS jsonb)
  WITH FUNCTION hive_data._operation_to_jsonb;

CREATE CAST (jsonb AS hive_data.operation)
  WITH FUNCTION hive_data._operation_from_jsonb;
