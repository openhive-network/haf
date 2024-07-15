DROP TYPE IF EXISTS hive.extract_set_witness_properties_return CASCADE;
CREATE TYPE hive.extract_set_witness_properties_return AS
(
  prop_name VARCHAR COLLATE "C", -- Name of deserialized property
  prop_value JSON -- Deserialized property
);

CREATE OR REPLACE FUNCTION hive.extract_set_witness_properties(IN prop_array hive.ctext)
RETURNS SETOF hive.extract_set_witness_properties_return
AS 'MODULE_PATHNAME', 'extract_set_witness_properties' LANGUAGE C;
