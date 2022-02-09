DO
$$
BEGIN
  CREATE TYPE hive.legacy_style_operation_return AS
  (
    body JSON --Body of operation in legacy style
  );
END
$$;

CREATE OR REPLACE FUNCTION hive.get_legacy_style_operation(IN _operation_body text)
RETURNS SETOF hive.legacy_style_operation_return
AS '$libdir/libhfm-@GIT_REVISION@.so', 'get_legacy_style_operation' LANGUAGE C;