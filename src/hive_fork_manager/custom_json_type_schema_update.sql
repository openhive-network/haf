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
-- Apps request one for the specific types they need with hive.register_custom_json_type_index().
-- This avoids indexing high-volume types like Splinterlands that most apps don't use.
--
-- The index is keyed on block number and partial on custom_json_type_id, like the ones of
-- hive.create_op_type_partial_index, so it serves block-range scans of the requested types
-- as well as whole-chain lookups of them.
-- The planner uses a partial index only when the query's custom_json_type_id condition
-- is provable at plan time: write the ids as literals (custom_json_type_id IN (2, 5)),
-- not as a function call or a parameter of a generic plan.

-- DEPRECATED: use hive.register_custom_json_type_index(), this function is going to be removed.
-- It builds the index with a plain CREATE INDEX on hafd.operations, which blocks hived's writes
-- for the whole build, and covers only the requested types hived has already met.
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
    RAISE WARNING 'hive.create_custom_json_type_index() is deprecated and will be removed: it builds the index without CONCURRENTLY, blocking hived''s writes to hafd.operations. Use hive.register_custom_json_type_index(<context name>, %) instead', quote_literal(_custom_json_ids);

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

-- Serializes reading hafd.custom_json_type_index_requests against reading hafd.custom_json_types:
-- without it a request and the arrival of its last type, in two concurrent transactions,
-- would each miss the other and the index would never be registered.
CREATE OR REPLACE FUNCTION hive.lock_custom_json_type_index_requests()
RETURNS VOID
LANGUAGE sql
AS $$
    SELECT pg_advisory_xact_lock( hashtext('hive_custom_json_type_index_requests') );
$$;

-- Registers the context's requested custom_json type index once every requested type has an id.
-- Registering an already registered index changes nothing.
CREATE OR REPLACE FUNCTION hive.register_requested_custom_json_type_index(_context_id INT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    __context_name TEXT;
    __custom_json_ids TEXT[];
    __type_ids SMALLINT[];
    __index_name TEXT;
BEGIN
    SELECT c.name, r.custom_json_ids INTO __context_name, __custom_json_ids
    FROM hafd.custom_json_type_index_requests r
    JOIN hafd.contexts c ON c.id = r.context_id
    WHERE r.context_id = _context_id;

    SELECT array_agg(id ORDER BY id) INTO __type_ids
    FROM hafd.custom_json_types
    WHERE custom_json_id = ANY(__custom_json_ids);

    IF cardinality(__type_ids) IS DISTINCT FROM cardinality(__custom_json_ids) THEN
        RAISE NOTICE 'custom_json type index of the context % waits for types % to appear', __context_name
            , ARRAY( SELECT unnest(__custom_json_ids) EXCEPT SELECT custom_json_id FROM hafd.custom_json_types );
        RETURN;
    END IF;

    __index_name := 'hive_operations_custom_json_block_num_' || array_to_string(__type_ids, '_') || '_idx';
    IF length(__index_name) > 63 THEN
        __index_name := 'hive_operations_custom_json_block_num_' || left(md5(array_to_string(__type_ids, ',')), 20) || '_idx';
    END IF;

    PERFORM hive.register_index_dependency(__context_name, format(
        'CREATE INDEX IF NOT EXISTS %I ON hafd.operations (hafd.operation_id_to_block_num(id)) WHERE custom_json_type_id IN (%s)',
        __index_name,
        array_to_string(__type_ids, ',')
    ));

    UPDATE hafd.custom_json_type_index_requests
    SET index_name = __index_name
    WHERE context_id = _context_id AND index_name IS DISTINCT FROM __index_name;
END;
$$;

-- Releases the context's custom_json type indexes other than its requested one, once that one is created:
-- until then they still serve the context's queries. One that hived is building is released
-- when it becomes created.
CREATE OR REPLACE FUNCTION hive.release_superseded_custom_json_type_indexes(_context_id INT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    __index_name TEXT;
BEGIN
    FOR __index_name IN
        SELECT superseded.index_constraint_name
        FROM hafd.custom_json_type_index_requests requested
        JOIN hafd.indexes_constraints current_index
            ON current_index.table_name = 'hafd.operations'
           AND current_index.index_constraint_name = requested.index_name
           AND current_index.status = 'created'
        JOIN hafd.indexes_constraints superseded
            ON superseded.table_name = 'hafd.operations'
           AND superseded.index_constraint_name LIKE 'hive\_operations\_custom\_json\_block\_num\_%'
           AND superseded.index_constraint_name <> requested.index_name
           AND superseded.status <> 'creating'
           AND requested.context_id = ANY(superseded.contexts)
        WHERE requested.context_id = _context_id
    LOOP
        RAISE NOTICE 'Releasing custom_json type index % superseded for the context %', __index_name, _context_id;
        PERFORM hive.remove_index_dependency(_context_id, 'hafd.operations', __index_name);
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION hive.on_custom_json_type_added()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hive, hafd, pg_catalog
AS $$
DECLARE
    __context_id INT;
BEGIN
    PERFORM hive.lock_custom_json_type_index_requests();
    FOR __context_id IN
        SELECT context_id FROM hafd.custom_json_type_index_requests
        WHERE index_name IS NULL AND NEW.custom_json_id = ANY(custom_json_ids)
    LOOP
        PERFORM hive.register_requested_custom_json_type_index(__context_id);
    END LOOP;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER hive_custom_json_type_added
AFTER INSERT ON hafd.custom_json_types
FOR EACH ROW
EXECUTE FUNCTION hive.on_custom_json_type_added();

-- Runs in the connection of hived's indexes controller, as part of its status update. A failure here would
-- make the controller treat the new index as failed and drop it, so it is reported instead; the superseded
-- indexes are then released by the context's next hive.register_custom_json_type_index call.
CREATE OR REPLACE FUNCTION hive.on_custom_json_type_index_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hive, hafd, pg_catalog
AS $$
DECLARE
    __context_id INT;
BEGIN
    FOREACH __context_id IN ARRAY NEW.contexts
    LOOP
        BEGIN
            PERFORM hive.release_superseded_custom_json_type_indexes(__context_id);
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Could not release the custom_json type indexes superseded for the context %: %', __context_id, SQLERRM;
        END;
    END LOOP;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER hive_custom_json_type_index_created
AFTER UPDATE OF status ON hafd.indexes_constraints
FOR EACH ROW
WHEN ( NEW.status = 'created' AND OLD.status <> 'created'
       AND NEW.table_name = 'hafd.operations'
       AND NEW.index_constraint_name LIKE 'hive\_operations\_custom\_json\_block\_num\_%' )
EXECUTE FUNCTION hive.on_custom_json_type_index_created();

-- Requests a partial index on hafd.operations, keyed on block number, for the given custom_json types
-- of the context. This is the supported way to index custom_json operations by type.
-- - The index is registered through hive.register_index_dependency, so hived's indexes controller
--   builds it with CREATE INDEX CONCURRENTLY.
-- - It is registered only once every requested type has an id in hafd.custom_json_types, i.e. hived
--   has met it in a block; a request made earlier is kept and acted on when the last type appears.
-- - Requesting the same set again changes nothing.
-- - A context has one such request: when it requests another set, its index for the previous set
--   is released once the index for the new set is created.
-- Call it in a short transaction: until it commits, hived waits before storing a type it has just met.
-- Raises insufficient_privilege unless the caller can impersonate the context's owner.
-- Example: SELECT hive.register_custom_json_type_index('nft_tracker_app', ARRAY['NFT']);
CREATE OR REPLACE FUNCTION hive.register_custom_json_type_index(_context_name TEXT, _custom_json_ids TEXT[])
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hive, hafd, pg_catalog
AS $$
DECLARE
    __context_id INT;
    __owner NAME;
    __custom_json_ids TEXT[];
BEGIN
    SELECT id, owner INTO __context_id, __owner
    FROM hafd.contexts
    WHERE name = _context_name;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'Context "%" not found in hafd.contexts', _context_name;
    END IF;

    -- see hive.app_remove_index_dependencies
    IF NOT hive.can_impersonate( session_user, __owner )
       AND NOT has_table_privilege( session_user, 'hafd.indexes_constraints', 'UPDATE, DELETE' ) THEN
        RAISE EXCEPTION 'User % is not an owner of context % and cannot register its custom_json type index', session_user, _context_name
            USING ERRCODE = 'insufficient_privilege';
    END IF;

    SELECT array_agg(DISTINCT custom_json_id ORDER BY custom_json_id)
    INTO __custom_json_ids
    FROM unnest(_custom_json_ids) AS custom_json_id;

    IF __custom_json_ids IS NULL OR EXISTS (
        SELECT 1 FROM unnest(__custom_json_ids) AS custom_json_id
        WHERE custom_json_id IS NULL OR custom_json_id = '' OR length(custom_json_id) > 32
    ) THEN
        RAISE EXCEPTION 'Invalid custom_json ids %, expected a non-empty list of 1 to 32 character ids', _custom_json_ids
            USING ERRCODE = '22023';
    END IF;

    PERFORM hive.lock_custom_json_type_index_requests();

    INSERT INTO hafd.custom_json_type_index_requests(context_id, custom_json_ids)
    VALUES (__context_id, __custom_json_ids)
    ON CONFLICT (context_id) DO UPDATE SET custom_json_ids = EXCLUDED.custom_json_ids, index_name = NULL
    WHERE hafd.custom_json_type_index_requests.custom_json_ids <> EXCLUDED.custom_json_ids;

    PERFORM hive.register_requested_custom_json_type_index(__context_id);
    PERFORM hive.release_superseded_custom_json_type_indexes(__context_id);
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
