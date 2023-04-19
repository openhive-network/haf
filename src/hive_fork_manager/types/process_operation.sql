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
  SELECT REPLACE(name, 'hive::protocol::', '')
    INTO STRICT __operation_type
    FROM hive.operation_types
    WHERE id = get_byte(operation::bytea, 0);

  BEGIN
    -- Check that given proc exists for actual operation type.
    -- Cast to regprocedure fails if it doesn't.
    -- In that case we catch it t not propagate it to the caller
    PERFORM (format('%I(hive.%I)', proc, __operation_type))::regprocedure;

    -- Call user provided function
    EXECUTE format('CALL %I($1::hive.%I)', proc, __operation_type)
      USING operation;
  EXCEPTION
    WHEN undefined_function THEN RETURN;
  END;
END;
$BODY$;
