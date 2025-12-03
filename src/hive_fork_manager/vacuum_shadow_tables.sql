-- Function to vacuum shadow tables for a specific context's registered application tables.
-- Returns the number of tables vacuumed.
CREATE OR REPLACE FUNCTION hive.vacuum_shadow_tables( _context_name TEXT )
RETURNS BIGINT
AS 'MODULE_PATHNAME', 'vacuum_shadow_tables' LANGUAGE C;
