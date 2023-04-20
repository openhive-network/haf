CREATE OR REPLACE FUNCTION hive.process_operation(
  operation hive.operation,
  proc TEXT
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
AS $BODY$
DECLARE
  __operation_type TEXT;
BEGIN
  -- Find the name of actual operation type
  SELECT hive.operation_type_name(operation) INTO STRICT __operation_type;

  -- Call user provided function, if it exists for given operation type
  IF (SELECT to_regprocedure(format('%I(hive.%I)', proc, __operation_type))) IS NOT NULL THEN
    EXECUTE format('CALL %I($1::hive.%I)', proc, __operation_type)
      USING operation;
  END IF;
END;
$BODY$;
