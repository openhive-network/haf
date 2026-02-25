-- =============================================================================
-- HAF API Implementation Functions (Refactored for unified tables with block_id)
-- =============================================================================
--
-- This file contains implementation functions for the HAF API.
-- The copy_*_to_irreversible functions have been removed since we now use
-- unified tables with block_id encoding instead of separate reversible tables.
--
-- Note: remove_orphan_forks is defined in hived_api.sql (not here) because
-- it needs explicit delete from all child tables (no CASCADE DELETE FKs exist).
-- =============================================================================

-- =============================================================================
-- remove_unecessary_events: Clean up old events from the queue
-- =============================================================================
CREATE OR REPLACE FUNCTION hive.remove_unecessary_events( _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __upper_bound_events_id BIGINT := NULL;
    __max_block_num INTEGER := NULL;
BEGIN
    SELECT hafd.block_id_to_num(consistent_block) INTO __max_block_num FROM hafd.hive_state;

    -- find the upper bound of events possible to remove
    SELECT MIN(heq.id) INTO __upper_bound_events_id
    FROM hafd.events_queue heq
    WHERE heq.event != 'BACK_FROM_FORK' AND heq.block_num = ( _new_irreversible_block + 1 ); --next block after irreversible

    -- You may think that SELECT FOR UPDATE needs to be used here in USING clause
    -- but SELECT FOR UPDATE will lock hafd.contexts, so it want to acquire lock
    -- between hived and application, and if application will modify contexts and never commit (by mistake or maliciously)
    -- then hived will be locked forever
    --
    -- Important notice from the pg documentation https://www.postgresql.org/docs/current/transaction-iso.html :
    -- UPDATE, DELETE, SELECT FOR UPDATE, and SELECT FOR SHARE commands behave the same as SELECT in terms of searching
    -- for target rows: they will only find target rows that were committed as of the command start time. However, such
    -- a target row might have already been updated (or deleted or locked) by another concurrent transaction by the
    -- time it is found.
    --
    -- It means that SELECT from USING clause will return min event = 10, but in case of a bug an application
    -- context may back to event 9 and then when DELETE is being committed it will violate FK(event_queue(id)<->contexts(events_id))

    DELETE FROM hafd.events_queue heq
    USING ( SELECT MIN( hc.events_id) as id FROM hafd.contexts hc ) as min_event
    WHERE ( heq.id < __upper_bound_events_id OR __upper_bound_events_id IS NULL )  AND ( heq.id < min_event.id OR min_event.id IS NULL ) AND heq.id != 0 AND heq.id != hive.unreachable_event_id();

END;
$BODY$
;

-- =============================================================================
-- Index/Constraint Management Functions
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.save_and_drop_indexes_constraints( in _schema TEXT, in _table TEXT )
    RETURNS VOID
    AS
$function$
DECLARE
    __command TEXT;
    __cursor REFCURSOR;
BEGIN
    PERFORM hive.save_and_drop_constraints( _schema, _table );

    --LEFT JOIN is needed in situation when PRIMARY KEY exists in a `_table`.
    --A method `hive.save_and_drop_constraints` finds it, but following code finds an index related to given PK as well.
    --Since dropping/restoring PK automatically drops/restores an index, then it's better to avoid storing a record with index related to PK.
    INSERT INTO hafd.indexes_constraints( index_constraint_name, table_name, command, is_constraint, is_index, is_foreign_key, contexts, status )
    SELECT
        T.indexname
      , _schema || '.' || _table
      , T.indexdef
      , FALSE as is_constraint
      , TRUE as is_index
      , FALSE as is_foreign_key
      , ARRAY[0]
      , 'missing' as status
    FROM
    (
      SELECT indexname, indexdef
      FROM pg_indexes
      WHERE schemaname = _schema AND tablename = _table
    ) T LEFT JOIN hafd.indexes_constraints ic ON( T.indexname = ic.index_constraint_name )
    ON CONFLICT (index_constraint_name, table_name) DO UPDATE
    SET status = 'missing';


    --dropping indexes
    OPEN __cursor FOR (
        SELECT ('DROP INDEX IF EXISTS '::TEXT || _schema || '.' || index_constraint_name || ';')
        FROM hafd.indexes_constraints WHERE table_name = _schema || '.' || _table AND is_index = TRUE
    );

    LOOP
    FETCH __cursor INTO __command;
        EXIT WHEN NOT FOUND;
        EXECUTE __command;
    END LOOP;
    CLOSE __cursor;

    --dropping primary keys/unique contraints
    OPEN __cursor FOR (
        SELECT ('ALTER TABLE '::TEXT || _schema || '.' || _table || ' DROP CONSTRAINT IF EXISTS ' || index_constraint_name || ';')
        FROM hafd.indexes_constraints WHERE table_name = _schema || '.' || _table AND is_constraint = TRUE
    );

    LOOP
    FETCH __cursor INTO __command;
        EXIT WHEN NOT FOUND;
        EXECUTE __command;
    END LOOP;
    CLOSE __cursor;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.save_and_drop_foreign_keys( in _table_schema TEXT, in _table_name TEXT )
RETURNS VOID
AS
$function$
DECLARE
    __command TEXT;
    __cursor REFCURSOR;
BEGIN
    INSERT INTO hafd.indexes_constraints( index_constraint_name, table_name, command, is_constraint, is_index, is_foreign_key, contexts, status )
    SELECT
          DISTINCT ON ( pgc.conname ) pgc.conname as constraint_name
        , _table_schema || '.' || _table_name as table_name
        , 'ALTER TABLE ' || tc.table_schema || '.' || tc.table_name || ' ADD CONSTRAINT ' || pgc.conname || ' ' || pg_get_constraintdef(pgc.oid) as command
        , FALSE as is_constraint
        , FALSE AS is_index
        , TRUE as is_foreign_key
        , ARRAY[0]
        , 'missing' as status
    FROM pg_constraint pgc
    JOIN pg_namespace nsp on nsp.oid = pgc.connamespace
    JOIN information_schema.table_constraints tc ON pgc.conname = tc.constraint_name AND nsp.nspname = tc.constraint_schema
    WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = _table_schema AND tc.table_name = _table_name
    ON CONFLICT (index_constraint_name, table_name) DO UPDATE
    SET status = 'missing';

    OPEN __cursor FOR (
        SELECT ('ALTER TABLE '::TEXT || _table_schema || '.' || _table_name || ' DROP CONSTRAINT IF EXISTS ' || index_constraint_name || ';')
        FROM hafd.indexes_constraints WHERE table_name = ( _table_schema || '.' || _table_name ) AND is_foreign_key = TRUE
    );

    LOOP
        FETCH __cursor INTO __command;
            EXIT WHEN NOT FOUND;
            EXECUTE __command;
    END LOOP;

    CLOSE __cursor;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.save_and_drop_constraints( in _table_schema TEXT, in _table_name TEXT )
RETURNS VOID
AS
$function$
DECLARE
__command TEXT;
__cursor REFCURSOR;
BEGIN
    INSERT INTO hafd.indexes_constraints( index_constraint_name, table_name, command, is_constraint, is_index, is_foreign_key, contexts, status )
    SELECT
        DISTINCT ON ( pgc.conname ) pgc.conname as constraint_name
        , _table_schema || '.' || _table_name as table_name
        , 'ALTER TABLE ' || tc.table_schema || '.' || tc.table_name || ' ADD CONSTRAINT ' || pgc.conname || ' ' || pg_get_constraintdef(pgc.oid) as command
        , tc.constraint_type = 'PRIMARY KEY' OR tc.constraint_type = 'UNIQUE' as is_constraint
        , FALSE AS is_index
        , FALSE as is_foreign_key
        , ARRAY[0]
        , 'missing' as status
    FROM pg_constraint pgc
        JOIN pg_namespace nsp on nsp.oid = pgc.connamespace
        JOIN information_schema.table_constraints tc ON pgc.conname = tc.constraint_name AND nsp.nspname = tc.constraint_schema
    WHERE tc.constraint_type != 'FOREIGN KEY' AND tc.table_schema = _table_schema AND tc.table_name = _table_name
    ON CONFLICT (index_constraint_name, table_name) DO UPDATE
    SET status = 'missing';

    OPEN __cursor FOR (
            SELECT ('ALTER TABLE '::TEXT || _table_schema || '.' || _table_name || ' DROP CONSTRAINT IF EXISTS ' || index_constraint_name || ';')
            FROM hafd.indexes_constraints WHERE table_name = ( _table_schema || '.' || _table_name ) AND is_foreign_key = TRUE
        );

        LOOP
    FETCH __cursor INTO __command;
                EXIT WHEN NOT FOUND;
                EXECUTE __command;
    END LOOP;

        CLOSE __cursor;
    END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.recluster_account_operations_if_index_dropped()
RETURNS VOID
AS
$function$
DECLARE
  __command TEXT;
  __cluster_index_dropped BOOLEAN;
BEGIN
  -- Check if the clustering index was dropped (uses unique constraint index)
  __cluster_index_dropped := EXISTS(
                SELECT command FROM hafd.indexes_constraints
                WHERE table_name = 'hafd.account_operations' AND
                      index_constraint_name = 'hive_account_operations_uq1' AND
                      status = 'missing' LIMIT 1);
  IF (__cluster_index_dropped) THEN
    RAISE NOTICE 'Cluster index dropped, restoring it before other indexes for faster clustering';
    SELECT command INTO __command FROM hafd.indexes_constraints
    WHERE table_name = 'hafd.account_operations' AND
          index_constraint_name = 'hive_account_operations_uq1' LIMIT 1;
    EXECUTE __command;
    RAISE NOTICE 'Clustering hafd.account_operations, this takes a while...';
    CLUSTER hafd.account_operations USING hive_account_operations_uq1;
    RAISE NOTICE 'Analyzing hafd.account_operations after clustering to update statistics';
    ANALYZE hafd.account_operations;
    UPDATE hafd.indexes_constraints SET status = 'created' WHERE command = __command;
  END IF;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.restore_indexes( in _table_name TEXT)
RETURNS VOID
AS
$function$
DECLARE
  __command TEXT;
  __start_time TIMESTAMP;
  __end_time TIMESTAMP;
  __duration INTERVAL;
BEGIN
  IF _table_name = 'hafd.account_operations' THEN
    PERFORM hive.recluster_account_operations_if_index_dropped();
  END IF;

  --restoring indexes, primary keys, unique constraints
  FOR __command IN
    SELECT command FROM hafd.indexes_constraints WHERE table_name = _table_name AND is_foreign_key = FALSE AND status = 'missing'
  LOOP
    RAISE NOTICE 'Restoring index: %', __command;
    UPDATE hafd.indexes_constraints SET status = 'creating' WHERE command = __command;
    __start_time := clock_timestamp();
    EXECUTE __command;
    __end_time := clock_timestamp();
    __duration := __end_time - __start_time;
    RAISE NOTICE 'Index % created in % seconds', __command, EXTRACT(EPOCH FROM __duration);
    UPDATE hafd.indexes_constraints SET status = 'created' WHERE command = __command;
  END LOOP;

  -- Improve planner statistics for tables with block_id columns.
  --
  -- Problem: PostgreSQL's ANALYZE samples too few rows to accurately estimate
  -- the number of distinct block_id values in large tables (e.g. estimates ~4M
  -- distinct block_ids in operations when actual is ~104M). This causes the
  -- planner to vastly overestimate rows per block_id in nested loop joins
  -- (e.g. 150K estimated vs 60 actual), inflating cost estimates to ~92M and
  -- triggering unnecessary JIT compilation (131ms overhead per query).
  --
  -- Fix: SET STATISTICS increases histogram resolution for better selectivity
  -- estimates. SET (n_distinct) overrides the sampled value with the correct
  -- ratio. A negative n_distinct value means "fraction of total rows that are
  -- distinct", so it scales automatically as the table grows.
  --
  -- How to recompute n_distinct if data characteristics change:
  --   1. Run: SELECT COUNT(DISTINCT block_id)::float / COUNT(*) FROM hafd.<table>;
  --      (or on a large sample: ... FROM hafd.<table> TABLESAMPLE SYSTEM(1))
  --   2. The result is the fraction to use as the negative n_distinct value.
  --   3. Verify with: EXPLAIN SELECT ... FROM <context>.operations_view WHERE block_num BETWEEN ...
  --      The estimated cost for a 10k block range should be below 100000 (jit_above_cost).
  IF _table_name = 'hafd.operations' THEN
    ALTER TABLE hafd.operations ALTER COLUMN block_id SET STATISTICS 10000;
    ALTER TABLE hafd.operations ALTER COLUMN block_id SET (n_distinct = -0.017); -- ~60 ops/block
  ELSIF _table_name = 'hafd.account_operations' THEN
    ALTER TABLE hafd.account_operations ALTER COLUMN block_id SET STATISTICS 10000;
    ALTER TABLE hafd.account_operations ALTER COLUMN block_id SET (n_distinct = -0.012); -- ~84 rows/block
  ELSIF _table_name = 'hafd.transactions' THEN
    ALTER TABLE hafd.transactions ALTER COLUMN block_id SET STATISTICS 10000;
    ALTER TABLE hafd.transactions ALTER COLUMN block_id SET (n_distinct = -0.025); -- ~40 txs/block
  ELSIF _table_name = 'hafd.blocks' THEN
    ALTER TABLE hafd.blocks ALTER COLUMN block_id SET STATISTICS 10000;
  END IF;

  EXECUTE format( 'ANALYZE %s',  _table_name );

  RAISE NOTICE 'Finished restoring any dropped indexes on %', _table_name;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.restore_foreign_keys( in _table_name TEXT )
    RETURNS VOID
AS
$function$
DECLARE
    __command TEXT;
    __cursor REFCURSOR;
BEGIN
    --restoring foreign keys
    OPEN __cursor FOR ( SELECT command FROM hafd.indexes_constraints WHERE table_name = _table_name AND is_foreign_key = TRUE AND status = 'missing' );
    LOOP
    FETCH __cursor INTO __command;
        EXIT WHEN NOT FOUND;
        EXECUTE __command;
        UPDATE hafd.indexes_constraints SET status = 'created' WHERE command = __command;
    END LOOP;
    CLOSE __cursor;

END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- =============================================================================
-- remove_inconsistent_irreversible_data: Clean up data after crash recovery
-- =============================================================================
-- Updated to work with block_id encoding. Uses block_id_to_num() to filter
-- blocks above the consistent block. Since there are no FKs between data tables,
-- we must explicitly delete from all tables.
-- =============================================================================
CREATE OR REPLACE FUNCTION hive.remove_inconsistent_irreversible_data()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __consistent_block INTEGER := NULL;
    __is_dirty BOOL := TRUE;
BEGIN
    SELECT COALESCE(hafd.block_id_to_num(consistent_block), 0), is_dirty INTO __consistent_block, __is_dirty FROM hafd.hive_state;

    IF ( __is_dirty = FALSE ) THEN
        RETURN;
    END IF;

    -- Delete from all data tables above consistent_block
    -- Order: child tables first to avoid any potential FK issues
    DELETE FROM hafd.account_operations ao
    WHERE hafd.block_id_to_num(ao.block_id) > __consistent_block;

    DELETE FROM hafd.applied_hardforks ah
    WHERE hafd.block_id_to_num(ah.block_id) > __consistent_block;

    DELETE FROM hafd.transactions_multisig tm
    WHERE hafd.block_id_to_num(tm.block_id) > __consistent_block;

    DELETE FROM hafd.operations o
    WHERE hafd.block_id_to_num(o.block_id) > __consistent_block;

    DELETE FROM hafd.transactions t
    WHERE hafd.block_id_to_num(t.block_id) > __consistent_block;

    -- Delete accounts created in blocks above consistent_block
    DELETE FROM hafd.accounts a
    WHERE hafd.block_id_to_num(a.block_id) > __consistent_block;

    -- Finally delete blocks
    DELETE FROM hafd.blocks hb
    WHERE hafd.block_id_to_num(hb.block_id) > __consistent_block;

    UPDATE hafd.hive_state SET is_dirty = FALSE;
END;
$BODY$
;

-- =============================================================================
-- Index Dependency Management Functions
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.register_index_dependency(
    _context_name TEXT,
    _create_index_command TEXT
)
RETURNS void
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __table_name TEXT;
    __index_name TEXT;
    __canonicalized_command TEXT;
    __context_id INT;
BEGIN
    -- Lookup the context_id using context_name
    SELECT id INTO __context_id
    FROM hafd.contexts
    WHERE name = _context_name;

        -- Abort with an error message if no context_id is found
    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'Context % not found in hafd.contexts', _context_name;
    END IF;

    -- Parse the index description
    SELECT table_name, index_name, canonicalized_command
    INTO __table_name, __index_name, __canonicalized_command
    FROM hive.parse_create_index_command(_create_index_command);

    -- Upsert the index dependency
    INSERT INTO hafd.indexes_constraints (
        table_name,
        index_constraint_name,
        command,
        is_constraint,
        is_index,
        is_foreign_key,
        status,
        contexts
    )
    VALUES (
        __table_name,
        __index_name,
        __canonicalized_command,
        FALSE,
        TRUE,
        FALSE,
        'missing',
        ARRAY[__context_id]
    )
    ON CONFLICT (table_name, index_constraint_name) DO UPDATE
    SET contexts = array_append(hafd.indexes_constraints.contexts, __context_id)
    WHERE NOT (__context_id = ANY(hafd.indexes_constraints.contexts));
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.check_if_registered_indexes_created(
    _app_context TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __context_id INT;
BEGIN
    RAISE NOTICE 'Checking if registered indexes are created for context %', _app_context;
    -- Lookup the context_id using context_name
    SELECT id INTO __context_id
    FROM hafd.contexts
    WHERE name = _app_context;

    -- Abort with an error message if no context_id is found
    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'Context % not found in hafd.contexts', _app_context;
    END IF;

    -- Check if there are any indexes that are not created yet
    RETURN NOT EXISTS (
        SELECT 1
        FROM hafd.indexes_constraints
        WHERE contexts @> ARRAY[__context_id] AND status <> 'created'
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.parse_create_index_command(
    create_index_command TEXT
)
RETURNS TABLE (
    table_name TEXT,
    index_name TEXT,
    canonicalized_command TEXT
)
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    _matches TEXT[];
BEGIN
    -- Extract the table name and index name using regex
    _matches := regexp_matches(create_index_command, '^\s*CREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:IF NOT EXISTS\s+)?(\w+)\s+ON\s+(\w+\.\w+)(?:\s+ONLY\s*)?', 'i');
    IF array_length(_matches, 1) = 2 THEN
        index_name := _matches[1];
        table_name := _matches[2];
    ELSE
        RAISE EXCEPTION 'Invalid CREATE INDEX command: %', create_index_command;
    END IF;

    -- Canonicalize the command by removing extra spaces and converting to lower case
    canonicalized_command := lower(regexp_replace(create_index_command, '\s+', ' ', 'g'));

    RETURN QUERY SELECT table_name, index_name, canonicalized_command;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.remove_index_dependencies(
    _context_name TEXT
)
RETURNS void
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __context_id INT;
    __index_record RECORD;
    _schema TEXT;
BEGIN
    -- Lookup the context_id using context_name
    SELECT id INTO __context_id
    FROM hafd.contexts
    WHERE name = _context_name;

    -- Abort with an error message if no context_id is found
    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'Context % not found in hafd.contexts', _context_name;
    END IF;

    -- Loop through each index that the context is dependent on
    FOR __index_record IN
        SELECT table_name, index_constraint_name
        FROM hafd.indexes_constraints
        WHERE contexts @> ARRAY[__context_id]
    LOOP
        -- Parse the schema name from the table field
        _schema := split_part(__index_record.table_name, '.', 1);

        -- Remove the context from the list of contexts
        UPDATE hafd.indexes_constraints
        SET contexts = array_remove(contexts, __context_id)
        WHERE table_name = __index_record.table_name AND index_constraint_name = __index_record.index_constraint_name;

        -- Drop the index if there are no remaining contexts dependent on it (note that HAF-internal dependencies are marked as being dependent on context 0 to prevent their removal)
        IF (SELECT array_length(contexts, 1) FROM hafd.indexes_constraints WHERE table_name = __index_record.table_name AND index_constraint_name = __index_record.index_constraint_name) IS NULL THEN
            EXECUTE 'DROP INDEX IF EXISTS ' || _schema || '.' || __index_record.index_constraint_name;
            DELETE FROM hafd.indexes_constraints WHERE table_name = __index_record.table_name AND index_constraint_name = __index_record.index_constraint_name;
        END IF;
    END LOOP;
END;
$BODY$
;

-- =============================================================================
-- Vacuum Request Functions
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.app_request_table_vacuum(
    _schema_name TEXT,
    _table_name TEXT,
    _min_interval INTERVAL DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    IF to_regclass(format('%I.%I', _schema_name, _table_name)) IS NULL THEN
        RAISE EXCEPTION 'Table %.% does not exist', _schema_name, _table_name
            USING ERRCODE = '42P01';
    END IF;

    IF _min_interval IS NOT NULL THEN
        -- Check if the table has been vacuumed recently
        IF EXISTS (
            SELECT 1
            FROM hafd.vacuum_requests
            WHERE schema_name = _schema_name
            AND table_name = _table_name
            AND last_vacuumed_time > NOW() - _min_interval
        ) THEN
            RAISE NOTICE 'Vacuum request for table %.% ignored due to recent vacuum.', _schema_name, _table_name;
            RETURN;
        END IF;
    END IF;

    -- Insert or update the vacuum request
    INSERT INTO hafd.vacuum_requests (schema_name, table_name, status)
    VALUES (_schema_name, _table_name, 'requested')
    ON CONFLICT (schema_name, table_name) DO UPDATE
    SET status = 'requested',
        error_message = NULL;

    RAISE NOTICE 'Vacuum request for table %.% submitted.', _schema_name, _table_name;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_request_table_vacuum(
    _qualified_table_name TEXT,
    _min_interval INTERVAL DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    _schema_name TEXT;
    _table_name TEXT;
    _parsed_ident TEXT[];
    _candidate_schema TEXT;
BEGIN
    _parsed_ident := parse_ident(_qualified_table_name);

    IF array_length(_parsed_ident, 1) = 2 THEN
        _schema_name := _parsed_ident[1];
        _table_name := _parsed_ident[2];
    ELSIF array_length(_parsed_ident, 1) = 1 THEN
        _table_name := _parsed_ident[1];

        FOREACH _candidate_schema IN ARRAY array_cat(ARRAY[CURRENT_SCHEMA], current_schemas(false)) LOOP
            IF to_regclass(format('%I.%I', _candidate_schema, _table_name)) IS NOT NULL THEN
                _schema_name := _candidate_schema;
                EXIT;
            END IF;
        END LOOP;

        IF _schema_name IS NULL THEN
            RAISE EXCEPTION 'Table % does not exist in search_path %', _table_name, current_setting('search_path')
                USING ERRCODE = '42P01';
        END IF;
    ELSE
        RAISE EXCEPTION 'Invalid table name: %', _qualified_table_name;
    END IF;

    PERFORM hive.app_request_table_vacuum(_schema_name, _table_name, _min_interval);
END;
$BODY$
;
