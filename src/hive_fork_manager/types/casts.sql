CREATE OR REPLACE FUNCTION hive._operation_to_comment_operation(
  hive.operation
) RETURNS hive.comment_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_comment_operation';

CREATE CAST (hive.operation AS hive.comment_operation)
  WITH FUNCTION hive._operation_to_comment_operation
  AS ASSIGNMENT;

