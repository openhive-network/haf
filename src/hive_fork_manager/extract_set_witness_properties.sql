DROP TYPE IF EXISTS hive.extract_set_witness_properties_return CASCADE;
CREATE TYPE hive.extract_set_witness_properties_return AS
(
  prop_name VARCHAR, -- Name of deserialized property
  prop_value JSON -- Deserialized property
);

CREATE OR REPLACE FUNCTION hive.extract_set_witness_properties(IN prop_array TEXT)
RETURNS SETOF hive.extract_set_witness_properties_return
AS '$libdir/libhfm-@HAF_GIT_REVISION_SHA@.so', 'extract_set_witness_properties' LANGUAGE C;
