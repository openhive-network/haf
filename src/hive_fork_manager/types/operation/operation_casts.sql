CREATE CAST (bytea AS hafd.operation)
  WITH FUNCTION hafd._operation_bin_in
  AS IMPLICIT;

CREATE CAST (hafd.operation AS bytea)
  WITH FUNCTION hafd._operation_bin_out
  AS IMPLICIT;

CREATE CAST (hafd.operation AS jsonb)
  WITH FUNCTION hafd._operation_to_jsonb;

CREATE CAST (jsonb AS hafd.operation)
  WITH FUNCTION hafd._operation_from_jsonb;
