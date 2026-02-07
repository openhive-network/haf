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

-- Generic partial index for all custom_json operations is NOT created by default.
-- Apps should call hive.create_custom_json_type_index() with the specific types they need.
-- This avoids indexing high-volume types like Splinterlands that most apps don't use.

-- Function to create an optimized partial index for specific custom_json types.
-- This should be called after replay when the custom_json_types table is populated.
-- Example: SELECT hive.create_custom_json_type_index(ARRAY['follow', 'reblog', 'community', 'notify']);
-- Note: SECURITY DEFINER allows HAF apps (like hivemind) to create indexes on hafd.operations
-- without needing direct ownership of the table.
CREATE OR REPLACE FUNCTION hive.create_custom_json_type_index(_custom_json_ids TEXT[])
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hive, hafd, pg_catalog
AS $$
DECLARE
    _type_ids SMALLINT[];
    _index_name TEXT;
    _where_clause TEXT;
BEGIN
    -- Look up the numeric IDs for the given custom_json_id strings
    SELECT array_agg(id ORDER BY id)
    INTO _type_ids
    FROM hafd.custom_json_types
    WHERE custom_json_id = ANY(_custom_json_ids);

    IF _type_ids IS NULL OR array_length(_type_ids, 1) IS NULL THEN
        RAISE NOTICE 'No matching custom_json_type_ids found for: %', _custom_json_ids;
        RETURN;
    END IF;

    -- Build a deterministic index name from the sorted IDs
    _index_name := 'hive_operations_custom_json_types_' || array_to_string(_type_ids, '_') || '_idx';

    -- Build the WHERE clause
    _where_clause := 'custom_json_type_id IN (' || array_to_string(_type_ids, ',') || ')';

    -- Check if index already exists
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = _index_name) THEN
        RAISE NOTICE 'Index % already exists', _index_name;
        RETURN;
    END IF;

    -- Create the partial index
    RAISE NOTICE 'Creating index % for custom_json types: % (IDs: %)', _index_name, _custom_json_ids, _type_ids;
    EXECUTE format(
        'CREATE INDEX %I ON hafd.operations (custom_json_type_id) WHERE %s',
        _index_name,
        _where_clause
    );
END;
$$;

-- Function to create an optimized partial index on hafd.operations for specific operation types.
-- Apps that only process a few op types (e.g., reputation_tracker uses 3 out of ~100+) can create
-- a partial index covering just their types, which is ~97% smaller than the full index.
-- The index key is block_num (matching range queries) with op_type_id in the WHERE clause.
-- Example: SELECT hive.create_op_type_partial_index(ARRAY[17, 61, 72]::SMALLINT[]);
-- Note: SECURITY DEFINER allows HAF apps to create indexes on hafd.operations
-- without needing direct ownership of the table.
CREATE OR REPLACE FUNCTION hive.create_op_type_partial_index(_op_type_ids SMALLINT[])
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hive, hafd, pg_catalog
AS $$
DECLARE
    _valid_ids SMALLINT[];
    _index_name TEXT;
    _where_clause TEXT;
BEGIN
    -- Validate that all provided IDs exist in hafd.operation_types
    SELECT array_agg(ot.id ORDER BY ot.id)
    INTO _valid_ids
    FROM hafd.operation_types ot
    WHERE ot.id = ANY(_op_type_ids);

    IF _valid_ids IS NULL OR array_length(_valid_ids, 1) IS NULL THEN
        RAISE NOTICE 'No matching operation type IDs found for: %', _op_type_ids;
        RETURN;
    END IF;

    IF array_length(_valid_ids, 1) != array_length(_op_type_ids, 1) THEN
        RAISE WARNING 'Some operation type IDs were not found. Requested: %, found: %', _op_type_ids, _valid_ids;
    END IF;

    -- Build a deterministic index name from the sorted IDs
    _index_name := 'hive_operations_op_types_' || array_to_string(_valid_ids, '_') || '_idx';

    -- Build the WHERE clause
    _where_clause := 'op_type_id IN (' || array_to_string(_valid_ids, ',') || ')';

    -- Check if index already exists
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = _index_name) THEN
        RAISE NOTICE 'Index % already exists', _index_name;
        RETURN;
    END IF;

    -- Create the partial index: key is block_num for range queries, partial on op_type_id
    RAISE NOTICE 'Creating index % for operation type IDs: %', _index_name, _valid_ids;
    EXECUTE format(
        'CREATE INDEX %I ON hafd.operations (hafd.operation_id_to_block_num(id)) WHERE %s',
        _index_name,
        _where_clause
    );
END;
$$;

-- Migration: Add op_type_id column to account_operations tables
-- This column stores the operation type, previously derivable from operation_id encoding.
-- After the encoding change (removing type from operation_id), it must be stored explicitly.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'hafd' AND table_name = 'account_operations' AND column_name = 'op_type_id'
    ) THEN
        ALTER TABLE hafd.account_operations ADD COLUMN op_type_id SMALLINT;
        -- Backfill from old encoding where type was stored in lowest 8 bits
        UPDATE hafd.account_operations SET op_type_id = (operation_id & 255)::smallint WHERE op_type_id IS NULL;
        ALTER TABLE hafd.account_operations ALTER COLUMN op_type_id SET NOT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'hafd' AND table_name = 'account_operations_reversible' AND column_name = 'op_type_id'
    ) THEN
        ALTER TABLE hafd.account_operations_reversible ADD COLUMN op_type_id SMALLINT;
        UPDATE hafd.account_operations_reversible SET op_type_id = (operation_id & 255)::smallint WHERE op_type_id IS NULL;
        ALTER TABLE hafd.account_operations_reversible ALTER COLUMN op_type_id SET NOT NULL;
    END IF;
END $$;
