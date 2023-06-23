-- SQL-side binary casts

CREATE CAST (bytea AS hive.operation)
  WITH FUNCTION hive._operation_bin_in
  AS IMPLICIT;

CREATE CAST (hive.operation AS bytea)
  WITH FUNCTION hive._operation_bin_out
  AS IMPLICIT;

CREATE CAST (hive.operation AS jsonb)
  WITH FUNCTION hive._operation_to_jsonb;

CREATE CAST (jsonb AS hive.operation)
  WITH FUNCTION hive._operation_from_jsonb;
