-- Migration: Add custom_json_types table and custom_json_type_id column
-- This runs during extension updates to add schema objects that are normally
-- created by irreversible_blocks.sql (SCHEMA_SOURCES) on fresh installs.
-- All statements use IF NOT EXISTS for idempotent execution.

CREATE TABLE IF NOT EXISTS hafd.custom_json_types (
    id SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    custom_json_id VARCHAR(32) NOT NULL UNIQUE
);

SELECT pg_catalog.pg_extension_config_dump('hafd.custom_json_types', '');

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'hafd' AND table_name = 'operations' AND column_name = 'custom_json_type_id'
    ) THEN
        ALTER TABLE hafd.operations ADD COLUMN custom_json_type_id SMALLINT DEFAULT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'hafd' AND table_name = 'operations_reversible' AND column_name = 'custom_json_type_id'
    ) THEN
        ALTER TABLE hafd.operations_reversible ADD COLUMN custom_json_type_id SMALLINT DEFAULT NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS hive_operations_custom_json_type_id_idx
    ON hafd.operations (custom_json_type_id) WHERE custom_json_type_id IS NOT NULL;
