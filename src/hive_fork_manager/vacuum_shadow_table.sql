-- Function to vacuum a single shadow table.
-- Returns true if vacuum succeeded.
CREATE OR REPLACE FUNCTION hive.vacuum_shadow_table( _table_name TEXT )
RETURNS BOOLEAN
AS 'MODULE_PATHNAME', 'vacuum_shadow_table' LANGUAGE C;
