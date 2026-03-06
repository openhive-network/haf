-- No-op stub: shadow table vacuum not needed in irreversible-only mode
CREATE OR REPLACE FUNCTION hive.vacuum_shadow_table( _table_name TEXT )
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN TRUE;
END;
$$;
