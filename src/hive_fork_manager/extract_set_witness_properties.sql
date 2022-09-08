DO
$$
BEGIN
  CREATE TYPE hive.extract_set_witness_properties_return AS
  (
    prop_name VARCHAR, -- Name of deserialized property
    prop_value JSON -- Deserialized property
  );
  EXCEPTION
    WHEN duplicate_object THEN null;
END
$$;

CREATE OR REPLACE FUNCTION hive.extract_set_witness_properties(IN prop_array TEXT, IN has_hardfork_24 BOOL)
RETURNS SETOF hive.extract_set_witness_properties_return
AS '$libdir/libhfm-@GIT_REVISION@.so', 'extract_set_witness_properties' LANGUAGE C;
