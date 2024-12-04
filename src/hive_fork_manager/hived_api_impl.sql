CREATE OR REPLACE FUNCTION hive.copy_blocks_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    SELECT
          DISTINCT ON ( hbr.num ) hbr.num
        , hbr.hash
        , hbr.prev
        , hbr.created_at
        , hbr.producer_account_id
        , hbr.transaction_merkle_root
        , hbr.extensions
        , hbr.witness_signature
        , hbr.signing_key

        , hbr.hbd_interest_rate

        , hbr.total_vesting_fund_hive
        , hbr.total_vesting_shares

        , hbr.total_reward_fund_hive
        , hbr.virtual_supply
        , hbr.current_supply
        , hbr.current_hbd_supply
        , hbr.dhf_interval_ledger

    FROM
        hafd.blocks_reversible hbr
    WHERE
        hbr.num <= _new_irreversible_block
    AND hbr.num > _head_block_of_irreversible_blocks
    ORDER BY hbr.num ASC, hbr.fork_id DESC;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.copy_transactions_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hafd.transactions
    SELECT
          htr.block_num
        , htr.trx_in_block
        , htr.trx_hash
        , htr.ref_block_num
        , htr.ref_block_prefix
        , htr.expiration
        , htr.signature
    FROM
        hafd.transactions_reversible htr
    JOIN ( SELECT
              DISTINCT ON ( hbr.num ) hbr.num
            , hbr.fork_id
            FROM hafd.blocks_reversible hbr
            WHERE
                    hbr.num <= _new_irreversible_block
                AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
    ) as num_and_forks ON htr.block_num = num_and_forks.num AND htr.fork_id = num_and_forks.fork_id
    ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.copy_operations_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hafd.operations
    SELECT
           hor.id
         , hor.trx_in_block
         , hor.op_pos
         , hor.body_binary
    FROM
        hafd.operations_reversible hor
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hafd.blocks_reversible hbr
            WHERE
                  hbr.num <= _new_irreversible_block
              AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
        ) as num_and_forks ON hive.operation_id_to_block_num(hor.id) = num_and_forks.num AND hor.fork_id = num_and_forks.fork_id
    ;
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.copy_applied_hardforks_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hafd.applied_hardforks
    SELECT
           hjr.hardfork_num
         , hjr.block_num
         , hjr.hardfork_vop_id
    FROM
        hafd.applied_hardforks_reversible hjr
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hafd.blocks_reversible hbr
            WHERE
                  hbr.num <= _new_irreversible_block
              AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
        ) as num_and_forks ON hjr.block_num = num_and_forks.num AND hjr.fork_id = num_and_forks.fork_id
    ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.copy_signatures_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hafd.transactions_multisig
    SELECT
          tsr.trx_hash
        , tsr.signature
    FROM
        hafd.transactions_multisig_reversible tsr
        JOIN hafd.transactions_reversible htr ON htr.trx_hash = tsr.trx_hash AND htr.fork_id = tsr.fork_id
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hafd.blocks_reversible hbr
            WHERE
                    hbr.num <= _new_irreversible_block
                AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
        ) as num_and_forks ON htr.block_num = num_and_forks.num AND htr.fork_id = num_and_forks.fork_id
    ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.copy_accounts_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hafd.accounts
    SELECT
           har.id
         , har.name
         , har.block_num
    FROM
        hafd.accounts_reversible har
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hafd.blocks_reversible hbr
            WHERE
                  hbr.num <= _new_irreversible_block
              AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
        ) as num_and_forks ON har.block_num = num_and_forks.num AND har.fork_id = num_and_forks.fork_id
    ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.copy_account_operations_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hafd.account_operations
    SELECT
           haor.account_id
         , haor.account_op_seq_no
         , haor.operation_id
    FROM
        hafd.account_operations_reversible haor
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hafd.blocks_reversible hbr
            WHERE
                hbr.num <= _new_irreversible_block
              AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
        ) as num_and_forks ON haor.fork_id = num_and_forks.fork_id AND hive.operation_id_to_block_num( haor.operation_id ) = num_and_forks.num
    ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.remove_obsolete_reversible_data( _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    -- up limit
    __max_fork_id hafd.fork.id%TYPE;
    -- down limit
    __min_ctx_fork_id hafd.fork.id%TYPE := hive.max_fork_id();
    __lowest_irreversible_block hafd.blocks.num%TYPE := hive.max_block_num();
    __max_block_num hafd.blocks.num%TYPE;
BEGIN
    SELECT max(hf.id) INTO __max_fork_id
    FROM hafd.fork hf;

    -- can only delete data from  blocks and forks already
    -- consumed by all the context, pair of lowest fork id and
    -- lowest irreversible block is a upper bound of deletion

    SELECT COALESCE( min(hc.fork_id), __min_ctx_fork_id )
         , COALESCE( min(irreversible_block), __lowest_irreversible_block )
    INTO __min_ctx_fork_id, __lowest_irreversible_block
    FROM hafd.contexts hc
    JOIN hafd.contexts_attachment hca ON hca.context_id = hc.id
    WHERE hca.is_attached = TRUE
    AND hc.is_forking = TRUE;

    __max_block_num := LEAST(__lowest_irreversible_block, _new_irreversible_block);

    DELETE FROM hafd.account_operations_reversible har
    USING hafd.operations_reversible hor
    WHERE
            har.operation_id = hor.id
        AND har.fork_id = hor.fork_id
        AND ( hive.operation_id_to_block_num(hor.id) <= __max_block_num OR hor.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id ) )
    ;

    DELETE FROM hafd.applied_hardforks_reversible hjr
    WHERE hjr.block_num <= __max_block_num OR hjr.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
    ;

    DELETE FROM hafd.operations_reversible hor
    WHERE hive.operation_id_to_block_num(hor.id) <= __max_block_num OR hor.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
    ;


    DELETE FROM hafd.transactions_multisig_reversible htmr
    USING hafd.transactions_reversible htr
    WHERE
            htr.fork_id = htmr.fork_id
        AND htr.trx_hash = htmr.trx_hash
        AND ( htr.block_num <= __max_block_num OR htr.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id ) )
    ;

    DELETE FROM hafd.transactions_reversible htr
    WHERE  htr.block_num <= __max_block_num OR htr.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
    ;

    DELETE FROM hafd.accounts_reversible har
    WHERE har.block_num <= __max_block_num OR har.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
    ;

    DELETE FROM hafd.blocks_reversible hbr
    WHERE hbr.num <= __max_block_num OR hbr.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
    ;
END;
$BODY$
;

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
    SELECT consistent_block INTO __max_block_num FROM hafd.irreversible_data;

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
    CLUSTER hafd.account_operations using hive_account_operations_uq1;
    RAISE NOTICE 'Analyzing hafd.account_operations after clustering to update statistics';
    ANALYZE hafd.account_operations;
    UPDATE hafd.indexes_constraints SET status = 'created' WHERE command = __command;
  END IF;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.restore_indexes( in _table_name TEXT, in concurrent BOOLEAN DEFAULT FALSE )
RETURNS VOID
AS
$function$
DECLARE
  __command TEXT;
  __original_command TEXT;
  __cursor REFCURSOR;
BEGIN

  IF _table_name = 'hafd.account_operations' THEN
    PERFORM hive.recluster_account_operations_if_index_dropped();
  END IF;

  --restoring indexes, primary keys, unique constraints
  OPEN __cursor FOR ( SELECT command FROM hafd.indexes_constraints WHERE table_name = _table_name AND is_foreign_key = FALSE AND status = 'missing' );
  LOOP
    FETCH __cursor INTO __original_command;
    EXIT WHEN NOT FOUND;
    IF concurrent THEN
      -- Modify the command to include CONCURRENTLY
      __command := regexp_replace(__original_command, 'CREATE INDEX', 'CREATE INDEX CONCURRENTLY', 'i');
    ELSE
      __command := __original_command;
    END IF;
    RAISE NOTICE 'Restoring index: %', __command;
    UPDATE hafd.indexes_constraints SET status = 'creating' WHERE command = __original_command;
    EXECUTE __command;
    UPDATE hafd.indexes_constraints SET status = 'created' WHERE command = __original_command;
  END LOOP;
  CLOSE __cursor;

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
    SELECT consistent_block, is_dirty INTO __consistent_block, __is_dirty FROM hafd.irreversible_data;

    IF ( __is_dirty = FALSE ) THEN
        RETURN;
    END IF;

    DELETE FROM hafd.account_operations hao
    WHERE hive.operation_id_to_block_num(hao.operation_id) > __consistent_block;

    DELETE FROM hafd.applied_hardforks WHERE block_num > __consistent_block;

    DELETE FROM hafd.operations WHERE hive.operation_id_to_block_num(id) > __consistent_block;

    DELETE FROM hafd.transactions_multisig htm
    USING hafd.transactions ht
    WHERE ht.block_num > __consistent_block AND ht.trx_hash = htm.trx_hash;

    DELETE FROM hafd.transactions WHERE block_num > __consistent_block;

    DELETE FROM hafd.accounts WHERE block_num > __consistent_block;

    DELETE FROM hafd.blocks WHERE num > __consistent_block;

    UPDATE hafd.irreversible_data SET is_dirty = FALSE;
END;
$BODY$
;

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
    SET contexts = array_append(hafd.indexes_constraints.contexts, __context_id);
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.wait_till_registered_indexes_created(
    _app_context TEXT
)
RETURNS void
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    index_record RECORD;
    __start_time TIMESTAMP;
    __end_time TIMESTAMP;
    __duration INTERVAL;
BEGIN
    RAISE NOTICE 'Starting to wait for registered indexes to be created for context %', _app_context;
    __start_time := clock_timestamp();

    LOOP
        EXIT WHEN NOT EXISTS (
        SELECT 1
        FROM hafd.indexes_constraints
        WHERE contexts @> ARRAY[(SELECT id FROM hafd.contexts WHERE name = _app_context)] AND status <> 'created'
        );
    END LOOP;


    __end_time := clock_timestamp();
    __duration := __end_time - __start_time;
    RAISE NOTICE 'Finished waiting for registered indexes to be created for context % in % seconds', _app_context, EXTRACT(EPOCH FROM __duration);
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
    _matches := regexp_matches(create_index_command, 'CREATE INDEX (\w+) ON (\w+\.\w+)');
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

CREATE OR REPLACE FUNCTION hive.test_index_dependencies()
RETURNS void
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __context_name TEXT;
    __index_command TEXT;
    __index_created BOOLEAN;
    __synchronization_stages hive.application_stages;
BEGIN
     __synchronization_stages := ARRAY[( 'MASSIVE_PROCESSING', 101, 10000 ), hive.live_stage()]::hive.application_stages;
    DROP SCHEMA IF EXISTS test_schema CASCADE; 
    CREATE SCHEMA test_schema;
    __context_name := 'test_context';
    __index_command := 'CREATE INDEX test_index ON hafd.account_operations (account_id)';

    RAISE NOTICE 'Creating context %', __context_name;
    PERFORM hive.app_create_context(__context_name, 'test_schema', __synchronization_stages);

    RAISE NOTICE 'Registering index dependency for context %', __context_name;
    PERFORM hive.register_index_dependency(__context_name, __index_command);
/*    
    RAISE NOTICE 'Waiting for registered indexes to be created for context %', __context_name;
    PERFORM hive.wait_till_registered_indexes_created(__context_name);


    RAISE NOTICE 'Remove index dependencies for context %', __context_name;
    PERFORM hive.remove_index_dependencies(__context_name);

    SELECT hive.app_remove_context(__context_name);
*/
    RAISE NOTICE 'Test for index dependencies completed for context %', __context_name;
END;
$BODY$
;
