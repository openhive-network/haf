-- -------------------------------------------------- APPLICATION MANAGED ROLLBACK SYSTEM -----------------------------------------
-- hive.app_transaction_table_register vs hive.register_table:
-- - Uses hafd.applications_transactions_register instead of hafd.contexts.
-- - Does not insert into hafd.registered_tables or hafd.triggers.
-- - Skips registered_table_id/is_attached/is_forking.
-- - Still creates shadow table, sequence, rowid index, trigger functions, and triggers.
-- => Provides HAF-like reversible tables with rollback fully managed by the application,
--    supporting multiple app-level transactions within a single HAF block.

-- ===================================================================
-- hive.app_transaction_table_register
-- ===================================================================

CREATE OR REPLACE FUNCTION hive.app_transaction_table_register(
    _table_schema TEXT,
    _table_name   TEXT,
    _context_name TEXT
)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __shadow_table_name TEXT := hive.get_shadow_table_name(_table_schema, _table_name);
    __hive_triggerfunction_name_insert TEXT := hive.get_trigger_insert_function_name(_table_schema, _table_name);
    __hive_triggerfunction_name_delete TEXT := hive.get_trigger_delete_function_name(_table_schema, _table_name);
    __hive_triggerfunction_name_update TEXT := hive.get_trigger_update_function_name(_table_schema, _table_name);
    __hive_triggerfunction_name_truncate TEXT := hive.get_trigger_truncate_function_name(_table_schema, _table_name);
    __new_sequence_name TEXT := 'seq_' || lower(_table_schema) || '_' || lower(_table_name);
    __columns_names TEXT[];
    __context_id INTEGER;
    __full_table_name TEXT := lower(_table_schema) || '.' || lower(_table_name);
BEGIN
    PERFORM hive.chceck_constrains(_table_schema, _table_name);

    -- verify that context exists in hafd.contexts and is not forking
    ASSERT EXISTS (
        SELECT 1 FROM hafd.contexts WHERE name = _context_name
    ), format('Context "%s" not found in hafd.contexts', _context_name);

    ASSERT EXISTS (
        SELECT 1 FROM hafd.contexts WHERE name = _context_name AND is_forking = FALSE
    ), format('Context "%s" is forking; application rollback works only with non-forking contexts', _context_name);

    -- ensure context exists in hafd.applications_transactions_register
    IF NOT EXISTS (SELECT 1 FROM hafd.applications_transactions_register WHERE name = _context_name) THEN
        INSERT INTO hafd.applications_transactions_register(name, owner)
        SELECT _context_name, current_user;
    END IF;

    -- ensure hive_rowid exists
    PERFORM 1
    FROM information_schema.columns
    WHERE table_schema = _table_schema
      AND table_name = _table_name
      AND column_name = 'hive_rowid';
    IF NOT FOUND THEN
        EXECUTE format('ALTER TABLE %I.%I ADD COLUMN hive_rowid BIGINT', _table_schema, _table_name);
    END IF;

    SELECT array_agg(iss.column_name::TEXT)
    FROM information_schema.columns iss
    WHERE iss.table_schema = _table_schema
      AND iss.table_name = _table_name
    INTO __columns_names;

    SELECT hive.create_shadow_table(_table_schema, _table_name)
    INTO __shadow_table_name;

    SELECT id FROM hafd.applications_transactions_register WHERE name = _context_name INTO __context_id;
    ASSERT __context_id IS NOT NULL, 'Context not found in hafd.applications_transactions_register';

    -- update registered_tables array (add if missing)
    UPDATE hafd.applications_transactions_register
    SET registered_tables =
            CASE
                WHEN NOT (__full_table_name = ANY(registered_tables))
                    THEN array_append(registered_tables, __full_table_name)
                ELSE registered_tables
                END
    WHERE name = _context_name;

    -- create and attach sequence for hive_rowid
    EXECUTE format('CREATE SEQUENCE IF NOT EXISTS %I.%s', lower(_table_schema), __new_sequence_name);
    EXECUTE format(
            'ALTER TABLE %I.%I ALTER COLUMN hive_rowid SET DEFAULT nextval(''%s.%s'')',
            lower(_table_schema), lower(_table_name),
            lower(_table_schema), __new_sequence_name
            );
    EXECUTE format(
            'ALTER SEQUENCE %I.%I OWNED BY %I.%I.hive_rowid',
            lower(_table_schema), __new_sequence_name,
            lower(_table_schema), lower(_table_name)
            );

    PERFORM hive.create_rowid_index(_table_schema, _table_name);
    PERFORM hive.create_revert_functions(_table_schema, _table_name, __shadow_table_name, __columns_names);

    -- Trigger functions use hafd.applications_transactions_register directly
    EXECUTE format($fmt$
        CREATE OR REPLACE FUNCTION %s()
        RETURNS trigger
        LANGUAGE plpgsql AS
        $$
        DECLARE __tx_id BIGINT; __rollback_in_progress BOOL;
        BEGIN
            SELECT rollback_in_progress INTO __rollback_in_progress
              FROM hafd.applications_transactions_register WHERE id=%s;
            IF __rollback_in_progress THEN RETURN NEW; END IF;

            SELECT current_app_tx_id INTO __tx_id
              FROM hafd.applications_transactions_register WHERE id=%s;
            IF __tx_id <= 0 THEN
                RAISE EXCEPTION 'Did not execute hive.context_next_tx before table edition';
            END IF;

            INSERT INTO hafd.%I SELECT n.*, __tx_id, 'INSERT'
            FROM new_table n ON CONFLICT DO NOTHING;
            RETURN NEW;
        END;
        $$;
    $fmt$, __hive_triggerfunction_name_insert, __context_id, __context_id, __shadow_table_name);

    EXECUTE format($fmt$
        CREATE OR REPLACE FUNCTION %s()
        RETURNS trigger
        LANGUAGE plpgsql AS
        $$
        DECLARE __tx_id BIGINT; __rollback_in_progress BOOL;
        BEGIN
            SELECT rollback_in_progress INTO __rollback_in_progress
              FROM hafd.applications_transactions_register WHERE id=%s;
            IF __rollback_in_progress THEN RETURN OLD; END IF;

            SELECT current_app_tx_id INTO __tx_id
              FROM hafd.applications_transactions_register WHERE id=%s;
            IF __tx_id <= 0 THEN
                RAISE EXCEPTION 'Did not execute hive.context_next_tx before table edition';
            END IF;

            INSERT INTO hafd.%I SELECT o.*, __tx_id, 'DELETE'
            FROM old_table o ON CONFLICT DO NOTHING;
            RETURN OLD;
        END;
        $$;
    $fmt$, __hive_triggerfunction_name_delete, __context_id, __context_id, __shadow_table_name);

    EXECUTE format($fmt$
        CREATE OR REPLACE FUNCTION %s()
        RETURNS trigger
        LANGUAGE plpgsql AS
        $$
        DECLARE __tx_id BIGINT; __rollback_in_progress BOOL;
        BEGIN
            SELECT rollback_in_progress INTO __rollback_in_progress
              FROM hafd.applications_transactions_register WHERE id=%s;
            IF __rollback_in_progress THEN RETURN NEW; END IF;

            SELECT current_app_tx_id INTO __tx_id
              FROM hafd.applications_transactions_register WHERE id=%s;
            IF __tx_id <= 0 THEN
                RAISE EXCEPTION 'Did not execute hive.context_next_tx before table edition';
            END IF;

            INSERT INTO hafd.%I SELECT o.*, __tx_id, 'UPDATE'
            FROM old_table o ON CONFLICT DO NOTHING;
            RETURN NEW;
        END;
        $$;
    $fmt$, __hive_triggerfunction_name_update, __context_id, __context_id, __shadow_table_name);

    EXECUTE format($fmt$
        CREATE OR REPLACE FUNCTION %s()
        RETURNS trigger
        LANGUAGE plpgsql AS
        $$
        DECLARE __tx_id BIGINT; __rollback_in_progress BOOL;
        BEGIN
            SELECT rollback_in_progress INTO __rollback_in_progress
              FROM hafd.applications_transactions_register WHERE id=%s;
            IF __rollback_in_progress THEN RETURN NULL; END IF;

            SELECT current_app_tx_id INTO __tx_id
              FROM hafd.applications_transactions_register WHERE id=%s;
            IF __tx_id <= 0 THEN
                RAISE EXCEPTION 'Did not execute hive.context_next_tx before table edition';
            END IF;

            INSERT INTO hafd.%I SELECT o.*, __tx_id, 'DELETE'
            FROM %I.%I o ON CONFLICT DO NOTHING;
            RETURN NULL;
        END;
        $$;
    $fmt$, __hive_triggerfunction_name_truncate, __context_id, __context_id, __shadow_table_name, _table_schema, _table_name);

    PERFORM hive.create_triggers(_table_schema, _table_name, __context_id);
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_transaction_table_unregister(
    _context_name TEXT,
    _table_schema TEXT,
    _table_name   TEXT
)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __shadow_table_name TEXT := hive.get_shadow_table_name(_table_schema, _table_name);
    __trigger_insert TEXT := hive.get_trigger_insert_name(_table_schema, _table_name);
    __trigger_delete TEXT := hive.get_trigger_delete_name(_table_schema, _table_name);
    __trigger_update TEXT := hive.get_trigger_update_name(_table_schema, _table_name);
    __trigger_truncate TEXT := hive.get_trigger_truncate_name(_table_schema, _table_name);
    __fn_insert TEXT := hive.get_trigger_insert_function_name(_table_schema, _table_name);
    __fn_delete TEXT := hive.get_trigger_delete_function_name(_table_schema, _table_name);
    __fn_update TEXT := hive.get_trigger_update_function_name(_table_schema, _table_name);
    __fn_truncate TEXT := hive.get_trigger_truncate_function_name(_table_schema, _table_name);
    __full_table_name TEXT := lower(_table_schema) || '.' || lower(_table_name);
    __is_registered BOOLEAN;
BEGIN
    -- Check if the table is registered in the given context
    SELECT EXISTS (
        SELECT 1
        FROM hafd.applications_transactions_register
        WHERE name = _context_name
          AND __full_table_name = ANY(registered_tables)
    )
    INTO __is_registered;

    IF NOT __is_registered THEN
        RAISE INFO 'Table "%" is not registered in context "%"; skipping unregister.', __full_table_name, _context_name;
        RETURN;
    END IF;

    -- Drop triggers (if exist)
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I.%I', __trigger_insert, _table_schema, _table_name);
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I.%I', __trigger_delete, _table_schema, _table_name);
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I.%I', __trigger_update, _table_schema, _table_name);
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I.%I', __trigger_truncate, _table_schema, _table_name);

    -- Drop trigger functions
    EXECUTE format('DROP FUNCTION IF EXISTS %s() CASCADE', __fn_insert);
    EXECUTE format('DROP FUNCTION IF EXISTS %s() CASCADE', __fn_delete);
    EXECUTE format('DROP FUNCTION IF EXISTS %s() CASCADE', __fn_update);
    EXECUTE format('DROP FUNCTION IF EXISTS %s() CASCADE', __fn_truncate);

    -- Drop shadow table
    EXECUTE format('DROP TABLE IF EXISTS hafd.%I CASCADE', __shadow_table_name);

    -- Drop related sequence
    EXECUTE format('DROP SEQUENCE IF EXISTS %I.seq_%s_%s CASCADE',
                   lower(_table_schema), lower(_table_schema), lower(_table_name));

    -- Remove the table from registered_tables array
    UPDATE hafd.applications_transactions_register
    SET registered_tables = array_remove(registered_tables, __full_table_name)
    WHERE name = _context_name;
END;
$BODY$;



-- ===================================================================
-- hive.app_managed_rollback
-- ===================================================================

CREATE OR REPLACE FUNCTION hive.app_transaction_rollback_on_table(
    _origin_table_schema TEXT,
    _origin_table_name   TEXT,
    _tx_id_before_rollback BIGINT = hive.unreachable_app_tx_id()
)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id INT;
    __shadow_table_name TEXT;
BEGIN
    SELECT id FROM hafd.applications_transactions_register LIMIT 1 INTO __context_id;
    ASSERT __context_id IS NOT NULL, 'No context row found in hafd.applications_transactions_register';

    UPDATE hafd.applications_transactions_register
    SET rollback_in_progress = TRUE
    WHERE id = __context_id AND current_app_tx_id > _tx_id_before_rollback;

    SET CONSTRAINTS ALL DEFERRED;

    SELECT hive.get_shadow_table_name(_origin_table_schema, _origin_table_name)
    INTO __shadow_table_name;

    PERFORM hive.back_from_fork_one_table(
            _origin_table_schema,
            _origin_table_name,
            __shadow_table_name,
            _tx_id_before_rollback
            );

    UPDATE hafd.applications_transactions_register
    SET current_app_tx_id = _tx_id_before_rollback,
        rollback_in_progress = FALSE
    WHERE id = __context_id AND current_app_tx_id > _tx_id_before_rollback;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_transaction_rollback(
    _context_name TEXT,
    _tx_id_before_rollback BIGINT = 0
)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- Mark rollback in progress for the given context
    UPDATE hafd.applications_transactions_register
    SET rollback_in_progress = TRUE
    WHERE name = _context_name
      AND current_app_tx_id > _tx_id_before_rollback;

    SET CONSTRAINTS ALL DEFERRED;

    -- Perform rollback on every table registered in this context
    PERFORM hive.app_transaction_rollback_on_table(
            split_part(t, '.', 1),   -- table schema
            split_part(t, '.', 2),   -- table name
            _tx_id_before_rollback
            )
    FROM unnest(
                 (SELECT registered_tables
                  FROM hafd.applications_transactions_register
                  WHERE name = _context_name)
         ) AS t;

    -- Update transaction state back to rollback point
    UPDATE hafd.applications_transactions_register
    SET current_app_tx_id = _tx_id_before_rollback,
        rollback_in_progress = FALSE
    WHERE name = _context_name
      AND current_app_tx_id > _tx_id_before_rollback;

    RAISE NOTICE 'Rolled back context "%" to transaction ID %.', _context_name, _tx_id_before_rollback;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_transaction_begin(
    _context_name TEXT
)
    RETURNS BIGINT
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __new_tx_id BIGINT;
BEGIN
    -- increment transaction id and return new value atomically
    UPDATE hafd.applications_transactions_register
    SET current_app_tx_id = current_app_tx_id + 1
    WHERE name = _context_name
    RETURNING current_app_tx_id INTO __new_tx_id;

    -- verify context existence
    ASSERT __new_tx_id IS NOT NULL,
        format('Context "%" not found in hafd.applications_transactions_register', _context_name);

    RETURN __new_tx_id;
END;
$BODY$;


CREATE OR REPLACE FUNCTION hive.app_transaction_commit_on_table(
    _origin_table_schema TEXT,
    _origin_table_name   TEXT,
    _tx_id_before_rollback BIGINT
)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __shadow_table_name TEXT;
    __sql TEXT;
BEGIN
    -- determine corresponding shadow table
    SELECT hive.get_shadow_table_name(_origin_table_schema, _origin_table_name)
    INTO __shadow_table_name;

    -- delete all shadow entries with tx id <= threshold, for all operation types
    __sql := format(
            'DELETE FROM hafd.%I WHERE hive_block_num <= %s',
            __shadow_table_name,
            _tx_id_before_rollback
    );

    EXECUTE __sql;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_transaction_commit(
    _context_name TEXT,
    _max_tx_id_to_commit BIGINT DEFAULT hive.unreachable_app_tx_id()  -- commit all transactions by default
)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- Commit transactions on all registered tables for the given context
    PERFORM hive.app_transaction_commit_on_table(
        split_part(t, '.', 1),   -- schema
        split_part(t, '.', 2),   -- table
        _max_tx_id_to_commit
    )
    FROM unnest(
        (SELECT registered_tables
        FROM hafd.applications_transactions_register
        WHERE name = _context_name)
    ) AS t;

    RAISE DEBUG 'Committed all transactions up to tx_id=% for context "%".',
        _max_tx_id_to_commit, _context_name;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_transaction_unregister_context(
    _context_name TEXT
)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- Unregister all app-managed rollback tables associated with the given context
    PERFORM hive.app_transaction_table_unregister(
            _context_name,
            split_part(t, '.', 1),
            split_part(t, '.', 2)
            )
    FROM unnest(
                 (SELECT registered_tables
                  FROM hafd.applications_transactions_register
                  WHERE name = _context_name)
    ) AS t;

    -- Remove the context entry from hafd.applications_transactions_register
    DELETE FROM hafd.applications_transactions_register WHERE name = _context_name;

    RAISE INFO 'All rollback-managed tables unregistered and context "%" removed from hafd.applications_transactions_register.', _context_name;
END;
$BODY$;


