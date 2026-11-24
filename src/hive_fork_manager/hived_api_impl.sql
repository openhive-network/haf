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
        , htr.rc_cost
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
         , hor.op_type_id
         , hor.op_pos
         , hor.body_value
         , hor.custom_json_type_id
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
        ) as num_and_forks ON hafd.operation_id_to_block_num(hor.id) = num_and_forks.num AND hor.fork_id = num_and_forks.fork_id
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
         , haor.transacting_account_id
         , haor.account_op_seq_no
         , haor.operation_id
         , haor.op_type_id
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
        ) as num_and_forks ON haor.fork_id = num_and_forks.fork_id AND hafd.operation_id_to_block_num( haor.operation_id ) = num_and_forks.num
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
    __max_fork_id BIGINT;
    -- down limit
    __min_ctx_fork_id BIGINT;
    __lowest_irreversible_block hafd.blocks.num%TYPE;
    __max_block_num hafd.blocks.num%TYPE;
BEGIN
    IF hive.is_lite_mode() THEN
        RETURN;
    END IF;

    __min_ctx_fork_id := hive.max_fork_id();
    __lowest_irreversible_block := hive.max_block_num();

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

    -- A row from an old fork is obsolete only if a later fork actually superseded it, i.e. some
    -- fork event with a higher id has its common block (hafd.fork.block_num) BELOW the row's height
    -- (the post-fork re-dump only covers blocks above the common block, and rows at or below it were
    -- never popped from hived's state).  An old-fork row at or below every later fork's common block
    -- is the only copy of that block and must be kept until it becomes irreversible (first condition),
    -- otherwise a subsequent hive.set_irreversible() finds nothing to copy and violates
    -- fk_1_hive_irreversible_data.  This can happen whenever a fork arrives while consistent_block
    -- lags behind the fork's common block.

    DELETE FROM hafd.account_operations_reversible har
    USING hafd.operations_reversible hor
    WHERE
            har.operation_id = hor.id
        AND har.fork_id = hor.fork_id
        AND ( hafd.operation_id_to_block_num(hor.id) <= __max_block_num
              OR ( hor.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
                   AND hafd.operation_id_to_block_num(hor.id) > ( SELECT MIN(hf2.block_num) FROM hafd.fork hf2 WHERE hf2.id > hor.fork_id ) ) )
    ;

    DELETE FROM hafd.applied_hardforks_reversible hjr
    WHERE hjr.block_num <= __max_block_num
       OR ( hjr.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
            AND hjr.block_num > ( SELECT MIN(hf2.block_num) FROM hafd.fork hf2 WHERE hf2.id > hjr.fork_id ) )
    ;

    DELETE FROM hafd.operations_reversible hor
    WHERE hafd.operation_id_to_block_num(hor.id) <= __max_block_num
       OR ( hor.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
            AND hafd.operation_id_to_block_num(hor.id) > ( SELECT MIN(hf2.block_num) FROM hafd.fork hf2 WHERE hf2.id > hor.fork_id ) )
    ;


    DELETE FROM hafd.transactions_multisig_reversible htmr
    USING hafd.transactions_reversible htr
    WHERE
            htr.fork_id = htmr.fork_id
        AND htr.trx_hash = htmr.trx_hash
        AND ( htr.block_num <= __max_block_num
              OR ( htr.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
                   AND htr.block_num > ( SELECT MIN(hf2.block_num) FROM hafd.fork hf2 WHERE hf2.id > htr.fork_id ) ) )
    ;

    DELETE FROM hafd.transactions_reversible htr
    WHERE  htr.block_num <= __max_block_num
       OR ( htr.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
            AND htr.block_num > ( SELECT MIN(hf2.block_num) FROM hafd.fork hf2 WHERE hf2.id > htr.fork_id ) )
    ;

    DELETE FROM hafd.accounts_reversible har
    WHERE har.block_num <= __max_block_num
       OR ( har.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
            AND har.block_num > ( SELECT MIN(hf2.block_num) FROM hafd.fork hf2 WHERE hf2.id > har.fork_id ) )
    ;

    DELETE FROM hafd.blocks_reversible hbr
    WHERE hbr.num <= __max_block_num
       OR ( hbr.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
            AND hbr.num > ( SELECT MIN(hf2.block_num) FROM hafd.fork hf2 WHERE hf2.id > hbr.fork_id ) )
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
    __min_context_events_id BIGINT := NULL;
BEGIN
    SELECT consistent_block INTO __max_block_num FROM hafd.hive_state;

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
    -- It means that SELECT below will return min event = 10, but in case of a bug an application
    -- context may back to event 9 and then when DELETE is being committed it will violate FK(event_queue(id)<->contexts(events_id))
    --
    -- The minimum is read once, before the DELETE: as a subquery joined to events_queue the cached generic
    -- plan re-scanned hafd.contexts, which has no index on events_id, once per events_queue row.
    -- events_id is not indexed on purpose: nearly every event updates it, and an index would make those updates non-HOT.
    SELECT MIN( hc.events_id ) INTO __min_context_events_id FROM hafd.contexts hc;

    DELETE FROM hafd.events_queue heq
    WHERE ( heq.id < __upper_bound_events_id OR __upper_bound_events_id IS NULL )  AND ( heq.id < __min_context_events_id OR __min_context_events_id IS NULL ) AND heq.id != 0 AND heq.id != hive.unreachable_event_id();

END;
$BODY$
;

-- The massive_sync_class a core index of the irreversible tables gets when it is first saved,
-- NULL for any other table.
-- 'keep': the leading key grows with the chain (block number, block or operation id, block time),
-- so hived's massive inserts append at the right edge of the btree and maintaining the index costs
-- almost nothing; these are also the indexes apps' block-range scans read. applied_hardforks is
-- kept as well: a few dozen rows ever, keyed by hardfork number and block number. So are the
-- accounts indexes: apps look accounts up by name and id on every batch they process, and the table
-- gets a row only per new account, so maintaining even its name index costs a few leaf inserts.
-- 'defer': the leading key is random with respect to insert order (transaction hash, account,
-- producer, operation type, json body), so every insert touches a random leaf.
-- Indexes this function does not know, e.g. ones an app created directly on a hafd table, are
-- deferred, except the block-number-keyed partial indexes of hive.register_op_type_partial_index.
CREATE OR REPLACE FUNCTION hive.default_massive_sync_index_class( _table_name TEXT, _index_constraint_name TEXT )
    RETURNS TEXT
    LANGUAGE sql
    IMMUTABLE
AS
$function$
SELECT CASE
    WHEN _table_name NOT IN ( 'hafd.blocks', 'hafd.transactions', 'hafd.transactions_multisig', 'hafd.operations'
                            , 'hafd.applied_hardforks', 'hafd.accounts', 'hafd.account_operations' ) THEN NULL
    WHEN ( _table_name, _index_constraint_name ) IN (
          ( 'hafd.blocks', 'pk_hive_blocks' )
        , ( 'hafd.blocks', 'hive_blocks_created_at_idx' )
        , ( 'hafd.transactions', 'hive_transactions_block_num_trx_in_block_idx' )
        , ( 'hafd.operations', 'pk_hive_operations' )
        , ( 'hafd.operations', 'hive_operations_block_num_id_idx' )
        , ( 'hafd.operations', 'hive_operations_block_num_trx_in_block_idx' )
        , ( 'hafd.applied_hardforks', 'pk_hive_applied_hardforks' )
        , ( 'hafd.applied_hardforks', 'hive_applied_hardforks_block_num_idx' )
        , ( 'hafd.accounts', 'pk_hive_accounts_id' )
        , ( 'hafd.accounts', 'uq_hive_accounst_name' )
        , ( 'hafd.accounts', 'hive_accounts_block_num_idx' )
    ) THEN 'keep'
    WHEN _table_name = 'hafd.operations' AND _index_constraint_name ~ '^hive_operations_op_types_[0-9a-f_]+_idx$' THEN 'keep'
    ELSE 'defer'
END;
$function$
;

-- Status a saved index or PK/UNIQUE constraint gets: 'created' when the massive sync keeps it
-- (it is not dropped), otherwise 'missing'.
CREATE OR REPLACE FUNCTION hive.massive_sync_index_status( _massive_sync_class TEXT, _keep_monotonic BOOLEAN )
    RETURNS hafd.index_status
    LANGUAGE sql
    IMMUTABLE
AS
$function$
SELECT CASE WHEN _keep_monotonic AND _massive_sync_class = 'keep' THEN 'created' ELSE 'missing' END::hafd.index_status;
$function$
;

-- _keep_monotonic: drop only the indexes and PK/UNIQUE constraints whose massive_sync_class is 'defer'
-- (psql-massive-index-policy=keep-monotonic); FALSE drops all of them.
CREATE OR REPLACE FUNCTION hive.save_and_drop_indexes_constraints( in _schema TEXT, in _table TEXT, in _keep_monotonic BOOLEAN DEFAULT FALSE )
    RETURNS VOID
    AS
$function$
DECLARE
    __command TEXT;
    __cursor REFCURSOR;
BEGIN
    PERFORM hive.save_and_drop_constraints( _schema, _table, _keep_monotonic );

    --LEFT JOIN is needed in situation when PRIMARY KEY exists in a `_table`.
    --A method `hive.save_and_drop_constraints` finds it, but following code finds an index related to given PK as well.
    --Since dropping/restoring PK automatically drops/restores an index, then it's better to avoid storing a record with index related to PK.
    INSERT INTO hafd.indexes_constraints( index_constraint_name, table_name, command, is_constraint, is_index, is_foreign_key, contexts, status, massive_sync_class )
    SELECT
        T.indexname
      , _schema || '.' || _table
      , T.indexdef
      , FALSE as is_constraint
      , TRUE as is_index
      , FALSE as is_foreign_key
      , ARRAY[0]
      , hive.massive_sync_index_status( hive.default_massive_sync_index_class( _schema || '.' || _table, T.indexname ), _keep_monotonic ) as status
      , hive.default_massive_sync_index_class( _schema || '.' || _table, T.indexname )
    FROM
    (
      SELECT indexname, indexdef
      FROM pg_indexes
      WHERE schemaname = _schema AND tablename = _table
    ) T LEFT JOIN hafd.indexes_constraints ic ON( T.indexname = ic.index_constraint_name )
    ON CONFLICT (index_constraint_name, table_name) DO UPDATE
    SET massive_sync_class = COALESCE( hafd.indexes_constraints.massive_sync_class, EXCLUDED.massive_sync_class )
      , status = hive.massive_sync_index_status( COALESCE( hafd.indexes_constraints.massive_sync_class, EXCLUDED.massive_sync_class ), _keep_monotonic );


    --dropping indexes; the ones still 'created' are kept by the policy
    OPEN __cursor FOR (
        SELECT ('DROP INDEX IF EXISTS '::TEXT || _schema || '.' || index_constraint_name || ';')
        FROM hafd.indexes_constraints WHERE table_name = _schema || '.' || _table AND is_index = TRUE AND status = 'missing'
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
        FROM hafd.indexes_constraints WHERE table_name = _schema || '.' || _table AND is_constraint = TRUE AND status = 'missing'
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

-- _keep_monotonic: see hive.save_and_drop_indexes_constraints
CREATE OR REPLACE FUNCTION hive.save_and_drop_constraints( in _table_schema TEXT, in _table_name TEXT, in _keep_monotonic BOOLEAN DEFAULT FALSE )
RETURNS VOID
AS
$function$
DECLARE
__command TEXT;
__cursor REFCURSOR;
BEGIN
    INSERT INTO hafd.indexes_constraints( index_constraint_name, table_name, command, is_constraint, is_index, is_foreign_key, contexts, status, massive_sync_class )
    SELECT
          T.constraint_name, T.table_name, T.command, T.is_constraint, FALSE AS is_index, FALSE as is_foreign_key, ARRAY[0]
        , hive.massive_sync_index_status( T.massive_sync_class, _keep_monotonic ) as status
        , T.massive_sync_class
    FROM (
        SELECT
            DISTINCT ON ( pgc.conname ) pgc.conname as constraint_name
            , _table_schema || '.' || _table_name as table_name
            , 'ALTER TABLE ' || tc.table_schema || '.' || tc.table_name || ' ADD CONSTRAINT ' || pgc.conname || ' ' || pg_get_constraintdef(pgc.oid) as command
            , tc.constraint_type = 'PRIMARY KEY' OR tc.constraint_type = 'UNIQUE' as is_constraint
            , CASE WHEN tc.constraint_type IN ( 'PRIMARY KEY', 'UNIQUE' ) THEN hive.default_massive_sync_index_class( _table_schema || '.' || _table_name, pgc.conname ) END as massive_sync_class
        FROM pg_constraint pgc
            JOIN pg_namespace nsp on nsp.oid = pgc.connamespace
            JOIN information_schema.table_constraints tc ON pgc.conname = tc.constraint_name AND nsp.nspname = tc.constraint_schema
        WHERE tc.constraint_type != 'FOREIGN KEY' AND tc.table_schema = _table_schema AND tc.table_name = _table_name
    ) T
    ON CONFLICT (index_constraint_name, table_name) DO UPDATE
    SET massive_sync_class = COALESCE( hafd.indexes_constraints.massive_sync_class, EXCLUDED.massive_sync_class )
      , status = hive.massive_sync_index_status( COALESCE( hafd.indexes_constraints.massive_sync_class, EXCLUDED.massive_sync_class ), _keep_monotonic );

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

-- The saved command of hive_account_operations_uq1 when it is 'missing', NULL otherwise.
CREATE OR REPLACE FUNCTION hive.missing_account_operations_cluster_index()
RETURNS TEXT
AS
$function$
  SELECT command FROM hafd.indexes_constraints
  WHERE table_name = 'hafd.account_operations' AND
        index_constraint_name = 'hive_account_operations_uq1' AND
        status = 'missing' LIMIT 1;
$function$
LANGUAGE sql STABLE
;

-- Builds hive_account_operations_uq1 when it is missing and leaves it 'creating' until
-- hive.cluster_account_operations marks it 'created': a restore interrupted between the two then
-- drops the index and builds it again, so the table is not left unclustered.
-- Returns TRUE when the index was built.
CREATE OR REPLACE FUNCTION hive.restore_account_operations_cluster_index()
RETURNS BOOLEAN
AS
$function$
DECLARE
  __command TEXT := hive.missing_account_operations_cluster_index();
BEGIN
  IF __command IS NULL THEN
    RETURN FALSE;
  END IF;

  RAISE NOTICE 'Cluster index dropped, restoring it before other indexes for faster clustering';
  UPDATE hafd.indexes_constraints SET status = 'creating' WHERE command = __command;
  EXECUTE __command;
  RETURN TRUE;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.cluster_account_operations()
RETURNS VOID
AS
$function$
BEGIN
  RAISE NOTICE 'Clustering hafd.account_operations, this takes a while...';
  CLUSTER hafd.account_operations using hive_account_operations_uq1;
  UPDATE hafd.indexes_constraints SET status = 'created'
  WHERE table_name = 'hafd.account_operations' AND index_constraint_name = 'hive_account_operations_uq1';
END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.recluster_account_operations_if_index_dropped()
RETURNS VOID
AS
$function$
BEGIN
  IF hive.restore_account_operations_cluster_index() THEN
    PERFORM hive.cluster_account_operations();
  END IF;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- How hive.proc_restore_indexes puts hafd.account_operations in (account_id, account_op_seq_no) order,
-- from the custom setting hive.account_operations_reorder: 'rewrite' (the default, when unset) for
-- hive.proc_reorder_account_operations, 'cluster' for CLUSTER on a prebuilt hive_account_operations_uq1.
CREATE OR REPLACE FUNCTION hive.account_operations_reorder_method()
RETURNS TEXT
AS
$function$
DECLARE
  __method TEXT := COALESCE( NULLIF( current_setting( 'hive.account_operations_reorder', TRUE ), '' ), 'rewrite' );
BEGIN
  IF __method NOT IN ( 'rewrite', 'cluster' ) THEN
    RAISE EXCEPTION 'hive.account_operations_reorder must be ''rewrite'' or ''cluster'', not ''%''', __method;
  END IF;
  RETURN __method;
END;
$function$
LANGUAGE plpgsql STABLE
;

-- How hive.proc_restore_indexes copies the sorted hafd.account_operations back into the truncated table,
-- from the custom setting hive.account_operations_copyback: 'insert' (the default, when unset) by
-- INSERT ... SELECT (hive.finish_account_operations_reorder), 'copy' by COPY ... FROM STDIN (FORMAT binary,
-- FREEZE), which writes the rows frozen and sets the visibility map of the pages it fills. COPY FREEZE must
-- be a top-level statement, so with 'copy' the procedure returns once the table is sorted and leaves the
-- copy-back to its caller (hive.start_account_operations_copyback); hived does it, and sets 'copy' for its
-- session unless the setting is set for the database or role.
CREATE OR REPLACE FUNCTION hive.account_operations_copyback_method()
RETURNS TEXT
AS
$function$
DECLARE
  __method TEXT := COALESCE( NULLIF( current_setting( 'hive.account_operations_copyback', TRUE ), '' ), 'insert' );
BEGIN
  IF __method NOT IN ( 'insert', 'copy' ) THEN
    RAISE EXCEPTION 'hive.account_operations_copyback must be ''insert'' or ''copy'', not ''%''', __method;
  END IF;
  RETURN __method;
END;
$function$
LANGUAGE plpgsql STABLE
;

-- Whether the free space of the filesystem that holds hafd.account_operations is enough for
-- hive.proc_reorder_account_operations: about twice the heap, plus a margin for the temp files of the
-- index builds running alongside it. The free space comes from hive.account_operations_reorder_free_space,
-- which hived sets from statvfs before the post-replay restore, or an operator sets for the database;
-- the space is not checked when it is unset. hive.account_operations_reorder_space_margin overrides
-- the margin, a tenth of the heap; a negative one lowers the requirement, e.g. on a compressing filesystem.
CREATE OR REPLACE FUNCTION hive.account_operations_reorder_space_suffices()
RETURNS BOOLEAN
AS
$function$
DECLARE
  __free_setting TEXT := NULLIF( current_setting( 'hive.account_operations_reorder_free_space', TRUE ), '' );
  __margin_setting TEXT := NULLIF( current_setting( 'hive.account_operations_reorder_space_margin', TRUE ), '' );
  __heap BIGINT := pg_relation_size( 'hafd.account_operations' );
  __needed BIGINT;
  __free BIGINT;
BEGIN
  IF __free_setting IS NULL THEN
    RAISE NOTICE 'Not checking the free space for the rewrite of hafd.account_operations: hive.account_operations_reorder_free_space is not set';
    RETURN TRUE;
  END IF;

  __free := pg_size_bytes( __free_setting );
  __needed := 2 * __heap + COALESCE( pg_size_bytes( __margin_setting ), __heap / 10 );
  IF __needed > __free THEN
    RAISE WARNING 'The rewrite of hafd.account_operations needs about % bytes (%) but only % bytes (%) are free: reordering it by CLUSTER instead (hive.account_operations_reorder). On a compressing filesystem the table''s logical size overstates the need, lower it with hive.account_operations_reorder_space_margin'
      , __needed, pg_size_pretty( __needed ), __free, pg_size_pretty( __free );
    RETURN FALSE;
  END IF;

  RAISE NOTICE 'The rewrite of hafd.account_operations needs about % bytes (%), % bytes (%) are free: reordering it by rewrite'
    , __needed, pg_size_pretty( __needed ), __free, pg_size_pretty( __free );
  RETURN TRUE;
END;
$function$
LANGUAGE plpgsql STABLE
;

-- Drops what an interrupted hive.proc_reorder_account_operations left behind.
CREATE OR REPLACE FUNCTION hive.drop_account_operations_reorder_tables()
RETURNS VOID
AS
$function$
DECLARE
  __table TEXT;
BEGIN
  FOR __table IN
    SELECT relname FROM pg_class
    WHERE relnamespace = 'hafd'::regnamespace AND relkind IN ( 'r', 'p' ) AND NOT relispartition
      AND relname LIKE 'account\_operations\_reorder\_%'
  LOOP
    EXECUTE format( 'DROP TABLE hafd.%I', __table );
  END LOOP;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- Prepares hive.proc_reorder_account_operations: unlogged staging partitions of hafd.account_operations,
-- each a range of account_id holding about _pages_per_step pages of rows, the bounds taken from a sample
-- of the table, and the steps of the reorder in hafd.account_operations_reorder_steps: a 'stage' step for
-- every _pages_per_step pages of the heap and a 'sort' step for every partition. Returns the size of the
-- heap in pages, for hive.finish_account_operations_reorder. The caller commits, so other sessions see the steps.
CREATE OR REPLACE FUNCTION hive.prepare_account_operations_reorder( in _pages_per_step INTEGER )
RETURNS BIGINT
AS
$function$
DECLARE
  __pages BIGINT;
  __buckets INTEGER;
  __bounds INTEGER[];
  __bucket INTEGER;
BEGIN
  IF _pages_per_step < 1 THEN
    RAISE EXCEPTION '_pages_per_step must be positive, not %', _pages_per_step;
  END IF;

  PERFORM hive.drop_account_operations_reorder_tables();
  __pages := pg_relation_size( 'hafd.account_operations' ) / current_setting( 'block_size' )::BIGINT;
  __buckets := GREATEST( 1, ceil( __pages::NUMERIC / _pages_per_step ) );

  -- SYSTEM sampling reads whole pages: about 10000 of them, or all of a small table
  EXECUTE format(
      'SELECT array_agg( DISTINCT bound ORDER BY bound ) FROM unnest(
         ( SELECT percentile_disc( ARRAY( SELECT generate_series( 1, %s - 1 )::FLOAT8 / %s ) ) WITHIN GROUP ( ORDER BY account_id )
           FROM hafd.account_operations TABLESAMPLE SYSTEM ( %s ) ) ) AS bound
       WHERE bound IS NOT NULL'
    , __buckets, __buckets, LEAST( 100, 100.0 * 10000 / GREATEST( __pages, 1 ) ) )
  INTO __bounds;
  __bounds := COALESCE( __bounds, '{}' );

  CREATE TABLE hafd.account_operations_reorder_staging ( LIKE hafd.account_operations ) PARTITION BY RANGE ( account_id );
  FOR __bucket IN 0 .. cardinality( __bounds ) LOOP
    EXECUTE format( 'CREATE UNLOGGED TABLE hafd.%I PARTITION OF hafd.account_operations_reorder_staging FOR VALUES FROM ( %s ) TO ( %s )'
      , 'account_operations_reorder_part_' || __bucket
      , COALESCE( __bounds[ __bucket ]::TEXT, 'MINVALUE' )
      , COALESCE( __bounds[ __bucket + 1 ]::TEXT, 'MAXVALUE' ) );
  END LOOP;

  -- arg is the first page of a 'stage' step and the partition of a 'sort' step; the 'heap' row, done from
  -- the start, holds the size of the heap in pages, and hive.end_account_operations_copyback adds a 'copied' row
  CREATE UNLOGGED TABLE hafd.account_operations_reorder_steps (
      kind TEXT NOT NULL
    , arg BIGINT NOT NULL
    , pages BIGINT
    , rows BIGINT
    , done BOOLEAN NOT NULL DEFAULT FALSE
    , PRIMARY KEY ( kind, arg )
  );
  INSERT INTO hafd.account_operations_reorder_steps( kind, arg, pages )
  SELECT 'stage', page, _pages_per_step FROM generate_series( 0, __pages - 1, _pages_per_step ) page
  UNION ALL
  SELECT 'sort', bucket, NULL FROM generate_series( 0, cardinality( __bounds ) ) bucket;
  INSERT INTO hafd.account_operations_reorder_steps( kind, arg, pages, done ) VALUES ( 'heap', 0, __pages, TRUE );

  RETURN __pages;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- Claims a step of the running hive.proc_reorder_account_operations that no session has done or is doing,
-- does it and marks it done, in the caller's transaction, which commits next. A 'stage' step copies its
-- pages of the heap into the staging partitions, a 'sort' step sorts its partition into an unlogged table
-- of its own; 'sort' steps are claimed only once every 'stage' step is done. Returns FALSE when there is
-- no step to claim: no reorder runs, or each of its steps is done or being done.
CREATE OR REPLACE FUNCTION hive.do_account_operations_reorder_step()
RETURNS BOOLEAN
AS
$function$
DECLARE
  __kind TEXT;
  __arg BIGINT;
  __pages BIGINT;
  __rows BIGINT;
BEGIN
  BEGIN
    EXECUTE
      'SELECT kind, arg, pages FROM hafd.account_operations_reorder_steps s
       WHERE NOT done AND ( kind = ''stage'' OR NOT EXISTS(
         SELECT 1 FROM hafd.account_operations_reorder_steps WHERE kind = ''stage'' AND NOT done ) )
       ORDER BY kind = ''sort'', arg LIMIT 1 FOR UPDATE OF s SKIP LOCKED'
    INTO __kind, __arg, __pages;
  EXCEPTION WHEN undefined_table THEN
    -- no reorder runs, or the one that ran has just dropped its tables
    RETURN FALSE;
  END;
  IF __kind IS NULL THEN
    RETURN FALSE;
  END IF;

  IF __kind = 'stage' THEN
    EXECUTE 'INSERT INTO hafd.account_operations_reorder_staging SELECT * FROM hafd.account_operations WHERE ctid >= $1 AND ctid < $2'
      USING format( '(%s,0)', __arg )::TID, format( '(%s,0)', __arg + __pages )::TID;
    GET DIAGNOSTICS __rows = ROW_COUNT;
  ELSE
    EXECUTE format( 'CREATE UNLOGGED TABLE hafd.%I AS SELECT * FROM hafd.%I ORDER BY account_id, account_op_seq_no'
      , 'account_operations_reorder_sorted_' || __arg, 'account_operations_reorder_part_' || __arg );
    GET DIAGNOSTICS __rows = ROW_COUNT;
    EXECUTE format( 'DROP TABLE hafd.%I', 'account_operations_reorder_part_' || __arg );
  END IF;

  EXECUTE 'UPDATE hafd.account_operations_reorder_steps SET done = TRUE, rows = $3 WHERE kind = $1 AND arg = $2'
    USING __kind, __arg, __rows;
  RETURN TRUE;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- Truncates hafd.account_operations for the copy-back of hive.proc_reorder_account_operations once each
-- of its steps is done, locking it until the caller's transaction ends. Fails when the heap is no longer
-- _pages pages long, i.e. it was written during the reorder.
CREATE OR REPLACE FUNCTION hive.truncate_account_operations_for_copyback( in _pages BIGINT )
RETURNS VOID
AS
$function$
BEGIN
  IF EXISTS( SELECT 1 FROM hafd.account_operations_reorder_steps WHERE NOT done ) THEN
    RAISE EXCEPTION 'The reorder of hafd.account_operations has steps that are not done';
  END IF;

  LOCK TABLE hafd.account_operations IN ACCESS EXCLUSIVE MODE;
  IF pg_relation_size( 'hafd.account_operations' ) / current_setting( 'block_size' )::BIGINT IS DISTINCT FROM _pages THEN
    RAISE EXCEPTION 'hafd.account_operations changed while it was being reordered';
  END IF;
  TRUNCATE hafd.account_operations;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- Fails when the _copied rows of the copy-back of hive.proc_reorder_account_operations differ from the staged ones.
CREATE OR REPLACE FUNCTION hive.check_account_operations_copyback( in _copied BIGINT )
RETURNS VOID
AS
$function$
DECLARE
  __staged BIGINT := ( SELECT COALESCE( sum( rows ), 0 ) FROM hafd.account_operations_reorder_steps WHERE kind = 'stage' );
BEGIN
  IF _copied IS DISTINCT FROM __staged THEN
    RAISE EXCEPTION 'Reordering hafd.account_operations staged % rows but copied %', __staged, _copied;
  END IF;
END;
$function$
LANGUAGE plpgsql STABLE
;

-- Ends hive.proc_reorder_account_operations once each of its steps is done: truncates hafd.account_operations
-- and appends the sorted tables to it in account_id order, a sequential copy without the sort CLUSTER does in
-- its single statement, then drops the reorder's tables. Fails when the heap is no longer _pages pages long,
-- i.e. it was written during the reorder, or when the copied row count differs from the staged one.
CREATE OR REPLACE FUNCTION hive.finish_account_operations_reorder( in _pages BIGINT )
RETURNS VOID
AS
$function$
DECLARE
  __copied BIGINT := 0;
  __rows BIGINT;
  __bucket BIGINT;
BEGIN
  PERFORM hive.truncate_account_operations_for_copyback( _pages );
  -- a synchronized scan could start in the middle of a sorted table
  PERFORM set_config( 'synchronize_seqscans', 'off', TRUE );
  FOR __bucket IN SELECT arg FROM hafd.account_operations_reorder_steps WHERE kind = 'sort' ORDER BY arg LOOP
    EXECUTE format( 'INSERT INTO hafd.account_operations SELECT * FROM hafd.%I', 'account_operations_reorder_sorted_' || __bucket );
    GET DIAGNOSTICS __rows = ROW_COUNT;
    __copied := __copied + __rows;
  END LOOP;
  PERFORM hive.check_account_operations_copyback( __copied );
  PERFORM hive.drop_account_operations_reorder_tables();
END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- The state of the reorder of hafd.account_operations whose copy-back hive.proc_restore_indexes leaves to
-- its caller (hive.account_operations_copyback_method): 'pending' once each step is done while the heap is
-- unchanged and the table has no index, 'copied' once the caller has copied the sorted table back
-- (hive.end_account_operations_copyback) while the heap is unchanged since, NULL otherwise.
CREATE OR REPLACE FUNCTION hive.account_operations_copyback_state()
RETURNS TEXT
AS
$function$
DECLARE
  __pages BIGINT := pg_relation_size( 'hafd.account_operations' ) / current_setting( 'block_size' )::BIGINT;
  __heap BIGINT;
  __copied BIGINT;
  __steps_left BOOLEAN;
BEGIN
  BEGIN
    EXECUTE
      'SELECT max( pages ) FILTER ( WHERE kind = ''heap'' ), max( pages ) FILTER ( WHERE kind = ''copied'' ), bool_or( NOT done )
       FROM hafd.account_operations_reorder_steps'
    INTO __heap, __copied, __steps_left;
  EXCEPTION WHEN undefined_table THEN
    RETURN NULL;
  END;

  IF __copied IS NOT NULL THEN
    RETURN CASE WHEN __copied = __pages THEN 'copied' END;
  END IF;
  IF __heap = __pages AND NOT __steps_left
     AND NOT EXISTS( SELECT 1 FROM pg_index WHERE indrelid = 'hafd.account_operations'::regclass ) THEN
    RETURN 'pending';
  END IF;
  RETURN NULL;
END;
$function$
LANGUAGE plpgsql STABLE
;

-- Starts the copy-back of the reorder of hafd.account_operations that hive.proc_restore_indexes left to its
-- caller: truncates the table and returns the sorted tables, in order, which the caller then streams into it,
-- in the same transaction, each by COPY hafd.account_operations FROM STDIN (FORMAT binary, FREEZE) fed from
-- COPY <sorted table> TO STDOUT (FORMAT binary) on another connection with synchronize_seqscans off, and ends
-- with hive.end_account_operations_copyback. For COPY FREEZE, it must be called by a top-level SELECT, with no
-- cursor open. Fails when the table has an index, which COPY would maintain row by row and which is to be
-- built after the copy-back, or when no reorder awaits its copy-back (hive.account_operations_copyback_state).
CREATE OR REPLACE FUNCTION hive.start_account_operations_copyback()
RETURNS SETOF TEXT
AS
$function$
BEGIN
  IF EXISTS( SELECT 1 FROM pg_index WHERE indrelid = 'hafd.account_operations'::regclass ) THEN
    RAISE EXCEPTION 'hafd.account_operations has indexes, its copy-back must run before they are built';
  END IF;
  IF hive.account_operations_copyback_state() IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'No reorder of hafd.account_operations awaits its copy-back';
  END IF;

  PERFORM hive.truncate_account_operations_for_copyback(
    ( SELECT pages FROM hafd.account_operations_reorder_steps WHERE kind = 'heap' ) );
  RETURN QUERY
    SELECT format( 'hafd.%I', 'account_operations_reorder_sorted_' || arg )
    FROM hafd.account_operations_reorder_steps WHERE kind = 'sort' ORDER BY arg;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- Ends the copy-back that hive.start_account_operations_copyback started in the caller's transaction, in
-- which the caller copied _copied rows: fails when they differ from the staged ones, drops the sorted tables
-- and records the copy-back, so that hive.proc_restore_indexes, CALLed again, goes on without reordering.
CREATE OR REPLACE FUNCTION hive.end_account_operations_copyback( in _copied BIGINT )
RETURNS VOID
AS
$function$
DECLARE
  __bucket BIGINT;
BEGIN
  PERFORM hive.check_account_operations_copyback( _copied );
  FOR __bucket IN SELECT arg FROM hafd.account_operations_reorder_steps WHERE kind = 'sort' LOOP
    EXECUTE format( 'DROP TABLE hafd.%I', 'account_operations_reorder_sorted_' || __bucket );
  END LOOP;
  DROP TABLE hafd.account_operations_reorder_staging;
  INSERT INTO hafd.account_operations_reorder_steps( kind, arg, pages, rows, done )
  VALUES ( 'copied', 0, pg_relation_size( 'hafd.account_operations' ) / current_setting( 'block_size' )::BIGINT, _copied, TRUE );
END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- Steps 1. and 2. of hive.proc_reorder_account_operations, committing after each step: prepares the reorder
-- (hive.prepare_account_operations_reorder), does its steps and waits for those that helpers are doing.
-- Must be CALLed outside a transaction block.
CREATE OR REPLACE PROCEDURE hive.proc_stage_and_sort_account_operations( in _pages_per_step INTEGER DEFAULT 1048576 )
LANGUAGE plpgsql
AS
$procedure$
DECLARE
  __step_time TIMESTAMP;
BEGIN
  PERFORM hive.prepare_account_operations_reorder( _pages_per_step );
  COMMIT;

  __step_time := clock_timestamp();
  LOOP
    IF hive.do_account_operations_reorder_step() THEN
      COMMIT;
      CONTINUE;
    END IF;
    EXIT WHEN NOT EXISTS( SELECT 1 FROM hafd.account_operations_reorder_steps WHERE NOT done );
    -- helpers are doing the last steps
    PERFORM pg_sleep( 1 );
    COMMIT;
  END LOOP;
  RAISE NOTICE 'Staged and sorted % rows of hafd.account_operations in % account ranges in % seconds'
    , ( SELECT sum( rows ) FROM hafd.account_operations_reorder_steps WHERE kind = 'stage' )
    , ( SELECT count(*) FROM hafd.account_operations_reorder_steps WHERE kind = 'sort' )
    , EXTRACT( EPOCH FROM clock_timestamp() - __step_time );
END;
$procedure$
;

-- Rewrites hafd.account_operations in (account_id, account_op_seq_no) order, keeping the table
-- itself (its OID, row type, grants, views, triggers and extension membership), and commits after
-- every step but the last, so that only the last one holds back the vacuum horizon for long:
-- 1. the heap is copied, _pages_per_step pages per transaction, into unlogged staging partitions,
--    each a range of account_id (hive.prepare_account_operations_reorder);
-- 2. each partition is sorted into an unlogged table of its own, one transaction each;
-- 3. one transaction truncates hafd.account_operations and appends the sorted tables to it in
--    account_id order (hive.finish_account_operations_reorder).
-- The steps of 1. and 2. are independent of each other, so sessions running hive.proc_help_restore_indexes
-- do them alongside this one (hive.do_account_operations_reorder_step); without them, this session does all.
-- Rows written to hafd.account_operations during the run would be lost, so it must run only while
-- nothing writes the table (hived's post-replay index restore); the last step fails, rolling back,
-- when the heap grew or the copied row count differs. Whatever indexes the table has are maintained
-- by the copy. Must be CALLed outside a transaction block.
CREATE OR REPLACE PROCEDURE hive.proc_reorder_account_operations( in _pages_per_step INTEGER DEFAULT 1048576 )
LANGUAGE plpgsql
AS
$procedure$
DECLARE
  __pages BIGINT;
  __start_time TIMESTAMP := clock_timestamp();
  __step_time TIMESTAMP;
BEGIN
  RAISE NOTICE 'Reordering hafd.account_operations by (account_id, account_op_seq_no)...';
  CALL hive.proc_stage_and_sort_account_operations( _pages_per_step );

  __step_time := clock_timestamp();
  __pages := ( SELECT pages FROM hafd.account_operations_reorder_steps WHERE kind = 'heap' );
  PERFORM hive.finish_account_operations_reorder( __pages );
  COMMIT;
  RAISE NOTICE 'Copied the sorted hafd.account_operations back in % seconds', EXTRACT( EPOCH FROM clock_timestamp() - __step_time );

  RAISE NOTICE 'Reordered hafd.account_operations in % seconds', EXTRACT( EPOCH FROM clock_timestamp() - __start_time );
END;
$procedure$
;

-- Resets the indexes and PK/UNIQUE constraints of the table stuck in 'creating' from a previous
-- interrupted run to 'missing', dropping what the interrupted build left behind
-- (e.g. the invalid index of a failed CREATE INDEX CONCURRENTLY).
CREATE OR REPLACE FUNCTION hive.reset_interrupted_index_restores( in _table_name TEXT )
RETURNS VOID
AS
$function$
DECLARE
  __name TEXT;
  __is_constraint BOOLEAN;
BEGIN
  FOR __name, __is_constraint IN
    SELECT index_constraint_name, is_constraint FROM hafd.indexes_constraints
    WHERE table_name = _table_name AND is_foreign_key = FALSE AND status = 'creating'
  LOOP
    RAISE NOTICE 'Resetting stuck index to missing: %', __name;
    IF __is_constraint THEN
      EXECUTE format('ALTER TABLE %s DROP CONSTRAINT IF EXISTS %I', _table_name, __name);
    END IF;
    EXECUTE format('DROP INDEX IF EXISTS %s.%I', split_part(_table_name, '.', 1), __name);
    UPDATE hafd.indexes_constraints SET status = 'missing'
    WHERE table_name = _table_name AND index_constraint_name = __name;
  END LOOP;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- Builds one saved index or PK/UNIQUE constraint and marks it 'created'.
CREATE OR REPLACE FUNCTION hive.restore_index( in _command TEXT )
RETURNS VOID
AS
$function$
DECLARE
  __constraint TEXT[];
  __start_time TIMESTAMP;
BEGIN
  RAISE NOTICE 'Restoring index: %', _command;
  UPDATE hafd.indexes_constraints SET status = 'creating' WHERE command = _command;
  __start_time := clock_timestamp();
  -- ADD CONSTRAINT would hold an ACCESS EXCLUSIVE lock for the whole index build, stalling apps that
  -- read the table while the restore runs; CREATE INDEX only takes a SHARE lock, and attaching the
  -- built index is a catalog change. Constraint definitions beyond columns and INCLUDE take the plain path.
  __constraint := regexp_match( _command, '^ALTER TABLE (\S+) ADD CONSTRAINT (\S+) (PRIMARY KEY|UNIQUE) (\([^()]*\)(?: INCLUDE \([^()]*\))?)$' );
  IF __constraint IS NULL THEN
    EXECUTE _command;
  ELSE
    EXECUTE format( 'CREATE UNIQUE INDEX %s ON %s %s', __constraint[2], __constraint[1], __constraint[4] );
    EXECUTE format( 'ALTER TABLE %s ADD CONSTRAINT %s %s USING INDEX %s', __constraint[1], __constraint[2], __constraint[3], __constraint[2] );
  END IF;
  RAISE NOTICE 'Index % created in % seconds', _command, EXTRACT(EPOCH FROM clock_timestamp() - __start_time);
  UPDATE hafd.indexes_constraints SET status = 'created' WHERE command = _command;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- Claims the table's 'missing' NOT NULL constraints that no session is restoring and that
-- hive.is_index_restore_ready, and restores them together in the caller's transaction: those the table
-- still has (the massive sync saves them but does not drop them) are only marked 'created', since
-- ADD CONSTRAINT would take an ACCESS EXCLUSIVE lock, queuing the table's readers behind it, to change
-- nothing; the others are added by one ALTER TABLE, which checks all of them in one scan of the table.
-- Returns FALSE when there is no constraint to claim.
CREATE OR REPLACE FUNCTION hive.restore_not_null_constraints( in _table_name TEXT )
RETURNS BOOLEAN
AS
$function$
DECLARE
  __names TEXT[];
  __present TEXT[];
  __subcommands TEXT[];
  __statement TEXT;
  __start_time TIMESTAMP;
BEGIN
  SELECT array_agg( c.index_constraint_name )
       , array_agg( c.index_constraint_name ) FILTER ( WHERE c.present )
       , array_agg( c.parts[1] ) FILTER ( WHERE NOT c.present )
  INTO __names, __present, __subcommands
  FROM (
    SELECT ic.index_constraint_name, m.parts
         , EXISTS( SELECT 1 FROM pg_constraint pgc
                   WHERE pgc.conrelid = _table_name::regclass AND pgc.contype = 'n' AND pgc.convalidated
                     AND pgc.conname = ic.index_constraint_name AND pg_get_constraintdef( pgc.oid ) = m.parts[2] ) AS present
    FROM (
      SELECT ic.index_constraint_name, ic.command
      FROM hafd.indexes_constraints ic
      WHERE ic.table_name = _table_name AND ic.is_foreign_key = FALSE AND ic.status = 'missing' AND NOT ic.is_constraint
        AND ic.command ~ '^ALTER TABLE \S+ ADD CONSTRAINT \S+ NOT NULL \S+$'
        AND hive.is_index_restore_ready( ic.table_name, ic.index_constraint_name )
      FOR UPDATE OF ic SKIP LOCKED
    ) ic
    CROSS JOIN LATERAL regexp_match( ic.command, '^ALTER TABLE \S+ (ADD CONSTRAINT \S+ (NOT NULL \S+))$' ) AS m( parts )
  ) c;

  IF __names IS NULL THEN
    RETURN FALSE;
  END IF;

  UPDATE hafd.indexes_constraints SET status = 'creating'
  WHERE table_name = _table_name AND index_constraint_name = ANY( __names );
  IF __present IS NOT NULL THEN
    RAISE NOTICE 'NOT NULL constraints of % already in place: %', _table_name, array_to_string( __present, ', ' );
  END IF;
  IF __subcommands IS NOT NULL THEN
    __statement := format( 'ALTER TABLE %s %s', _table_name, array_to_string( __subcommands, ', ' ) );
    RAISE NOTICE 'Restoring NOT NULL constraints: %', __statement;
    __start_time := clock_timestamp();
    EXECUTE __statement;
    RAISE NOTICE 'NOT NULL constraints of % created in % seconds', _table_name, EXTRACT(EPOCH FROM clock_timestamp() - __start_time);
  END IF;
  UPDATE hafd.indexes_constraints SET status = 'created'
  WHERE table_name = _table_name AND index_constraint_name = ANY( __names );
  RETURN TRUE;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- Restores the table's indexes and PK/UNIQUE and NOT NULL constraints in the caller's transaction.
-- hive.proc_restore_indexes does the same, committing each statement on its own.
CREATE OR REPLACE FUNCTION hive.restore_indexes( in _table_name TEXT)
RETURNS VOID
AS
$function$
DECLARE
  __command TEXT;
BEGIN
  PERFORM hive.reset_interrupted_index_restores( _table_name );

  IF _table_name = 'hafd.account_operations' THEN
    PERFORM hive.recluster_account_operations_if_index_dropped();
  END IF;

  PERFORM hive.restore_not_null_constraints( _table_name );
  FOR __command IN
    SELECT command FROM hafd.indexes_constraints WHERE table_name = _table_name AND is_foreign_key = FALSE AND status = 'missing'
  LOOP
    PERFORM hive.restore_index( __command );
  END LOOP;

  EXECUTE format( 'ANALYZE %s',  _table_name );

  RAISE NOTICE 'Finished restoring any dropped indexes on %', _table_name;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- The session-level advisory lock that hive.proc_restore_indexes of the table holds while it runs.
CREATE OR REPLACE FUNCTION hive.index_restore_lock_key( in _table_name TEXT )
RETURNS BIGINT
AS
$function$
  SELECT hashtextextended( 'hive.proc_restore_indexes ' || _table_name, 0 );
$function$
LANGUAGE sql IMMUTABLE
;

-- How many sessions hived runs hive.proc_help_restore_indexes in alongside its post-replay
-- hive.proc_restore_indexes of the table, on a host with _cores hardware threads: the custom setting
-- hive.index_restore_helpers, for every table, when it is set; otherwise, for hafd.account_operations,
-- whose reorder is the longest restore, one for every 8 threads beyond the first 8, at most 3, and
-- none for the other tables, whose index builds run alongside it.
CREATE OR REPLACE FUNCTION hive.index_restore_helpers( in _table_name TEXT, in _cores INTEGER )
RETURNS INTEGER
AS
$function$
DECLARE
  __setting TEXT := NULLIF( current_setting( 'hive.index_restore_helpers', TRUE ), '' );
BEGIN
  IF __setting IS NOT NULL THEN
    IF __setting !~ '^[0-9]{1,4}$' THEN
      RAISE EXCEPTION 'hive.index_restore_helpers must be a number of sessions, not ''%''', __setting;
    END IF;
    RETURN __setting::INTEGER;
  END IF;

  IF _table_name = 'hafd.account_operations' THEN
    RETURN LEAST( 3, GREATEST( 0, _cores / 8 - 1 ) );
  END IF;
  RETURN 0;
END;
$function$
LANGUAGE plpgsql STABLE
;

-- The transaction-level advisory lock that hive.proc_restore_indexes holds while it builds
-- hive_account_operations_uq1 on the reordered hafd.account_operations.
CREATE OR REPLACE FUNCTION hive.account_operations_cluster_index_lock_key()
RETURNS BIGINT
AS
$function$
  SELECT hashtextextended( 'hive.proc_restore_indexes hive_account_operations_uq1', 0 );
$function$
LANGUAGE sql IMMUTABLE
;

-- Whether a session holds hive.account_operations_cluster_index_lock_key, i.e. builds hive_account_operations_uq1
-- on the reordered hafd.account_operations, which no CLUSTER rewrites afterwards. pg_locks splits a bigint key
-- into classid (high half) and objid (low half), objsubid 1.
CREATE OR REPLACE FUNCTION hive.is_account_operations_cluster_index_building()
RETURNS BOOLEAN
AS
$function$
  SELECT EXISTS( SELECT 1 FROM pg_locks
                 WHERE locktype = 'advisory' AND granted AND objsubid = 1
                   AND database = ( SELECT oid FROM pg_database WHERE datname = current_database() )
                   AND classid::BIGINT = ( hive.account_operations_cluster_index_lock_key() >> 32 ) & 4294967295
                   AND objid::BIGINT = hive.account_operations_cluster_index_lock_key() & 4294967295 );
$function$
LANGUAGE sql STABLE
;

-- Whether hive.restore_next_index may build the index or constraint: any but those of hafd.account_operations,
-- whose hive_account_operations_uq1 hive.proc_restore_indexes builds with the table's reorder, and whose
-- other indexes wait for that, i.e. until hive_account_operations_uq1 is past 'missing' and 'creating'.
-- Only its plain indexes go ahead while hive_account_operations_uq1 is built on the reordered table
-- (hive.is_account_operations_cluster_index_building): CREATE INDEX takes the SHARE lock the build holds,
-- while the constraints would queue an ACCESS EXCLUSIVE lock behind it, stalling the other index builds.
CREATE OR REPLACE FUNCTION hive.is_index_restore_ready( in _table_name TEXT, in _index_constraint_name TEXT )
RETURNS BOOLEAN
AS
$function$
  SELECT _table_name <> 'hafd.account_operations' OR (
    _index_constraint_name <> 'hive_account_operations_uq1'
    AND ( NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints
                      WHERE table_name = 'hafd.account_operations' AND index_constraint_name = 'hive_account_operations_uq1'
                        AND status IN ( 'missing', 'creating' ) )
          OR ( EXISTS( SELECT 1 FROM hafd.indexes_constraints
                       WHERE table_name = 'hafd.account_operations' AND index_constraint_name = _index_constraint_name AND is_index )
               AND hive.is_account_operations_cluster_index_building() ) ) );
$function$
LANGUAGE sql STABLE
;

-- Claims a 'missing' index or PK/UNIQUE constraint of the table that no session is building and builds
-- it with hive.restore_index, or the table's NOT NULL constraints with hive.restore_not_null_constraints,
-- in the caller's transaction, which commits next, if hive.is_index_restore_ready. Returns FALSE when
-- there is nothing to claim.
-- Attaching a constraint's index needs an ACCESS EXCLUSIVE lock, which would wait, stalling the readers
-- of the table queued behind it, for every index build of another session, or deadlock with another
-- attach: so a table's PK/UNIQUE constraints are built one at a time, and its NOT NULL constraints and
-- plain indexes only after them, but for hive_account_operations_uq1, which hive.proc_restore_indexes builds
-- and attaches in its own transaction (hive.is_index_restore_ready).
CREATE OR REPLACE FUNCTION hive.restore_next_index( in _table_name TEXT )
RETURNS BOOLEAN
AS
$function$
DECLARE
  __command TEXT;
BEGIN
  IF pg_try_advisory_xact_lock( hashtextextended( 'hive.restore_next_index ' || _table_name, 0 ) ) THEN
    SELECT ic.command INTO __command
    FROM hafd.indexes_constraints ic
    WHERE ic.table_name = _table_name AND ic.is_foreign_key = FALSE AND ic.status = 'missing' AND ic.is_constraint
      AND hive.is_index_restore_ready( ic.table_name, ic.index_constraint_name )
    LIMIT 1
    FOR UPDATE OF ic SKIP LOCKED;
  END IF;

  IF __command IS NULL AND NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints
                                       WHERE table_name = _table_name AND is_foreign_key = FALSE AND status = 'missing' AND is_constraint )
     AND hive.restore_not_null_constraints( _table_name ) THEN
    RETURN TRUE;
  END IF;

  IF __command IS NULL THEN
    SELECT ic.command INTO __command
    FROM hafd.indexes_constraints ic
    WHERE ic.table_name = _table_name AND ic.is_foreign_key = FALSE AND ic.status = 'missing' AND NOT ic.is_constraint
      AND hive.is_index_restore_ready( ic.table_name, ic.index_constraint_name )
      AND NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints
                      WHERE table_name = _table_name AND is_foreign_key = FALSE AND status = 'missing' AND is_constraint
                        AND NOT ( table_name = 'hafd.account_operations' AND index_constraint_name = 'hive_account_operations_uq1'
                                  AND hive.is_account_operations_cluster_index_building() ) )
    LIMIT 1
    FOR UPDATE OF ic SKIP LOCKED;
  END IF;

  IF __command IS NULL THEN
    RETURN FALSE;
  END IF;
  PERFORM hive.restore_index( __command );
  RETURN TRUE;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

-- Helps a hive.proc_restore_indexes of the table that runs in another session: does steps of the
-- reorder of hafd.account_operations (hive.do_account_operations_reorder_step) and builds the table's
-- indexes that are ready (hive.restore_next_index), committing after each. Returns once the table has
-- no index left to restore, or when no session holds hive.index_restore_lock_key of the table, which
-- hived takes before it starts helpers. A helper that fails loses nothing: what it did not commit
-- is done by the restore. Must be CALLed outside a transaction block.
CREATE OR REPLACE PROCEDURE hive.proc_help_restore_indexes( in _table_name TEXT )
LANGUAGE plpgsql
AS
$procedure$
DECLARE
  __lock_key BIGINT := hive.index_restore_lock_key( _table_name );
BEGIN
  LOOP
    IF _table_name = 'hafd.account_operations' THEN
      IF hive.do_account_operations_reorder_step() THEN
        COMMIT;
        CONTINUE;
      END IF;
      -- releases the reorder's steps, which hive.proc_restore_indexes drops while this session may build an index
      COMMIT;
    END IF;
    IF hive.restore_next_index( _table_name ) THEN
      COMMIT;
      CONTINUE;
    END IF;

    EXIT WHEN NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints
                          WHERE table_name = _table_name AND is_foreign_key = FALSE AND status IN ( 'missing', 'creating' ) );
    IF pg_try_advisory_lock_shared( __lock_key ) THEN
      PERFORM pg_advisory_unlock_shared( __lock_key );
      EXIT;
    END IF;
    PERFORM pg_sleep( 1 );
    COMMIT;
  END LOOP;
END;
$procedure$
;

-- hive.restore_indexes, committing after each index build, the reorder of hafd.account_operations
-- and the ANALYZE, so a restore holds back the vacuum horizon only for the statement that is running,
-- not for the whole table. hafd.account_operations is reordered as hive.account_operations_reorder_method
-- says, by CLUSTER when hive.account_operations_reorder_space_suffices finds too little free space for
-- the rewrite. Sessions running hive.proc_help_restore_indexes share the reorder's steps and the index
-- builds with it; it holds hive.index_restore_lock_key while it runs. When the rewrite's copy-back is
-- left to the caller (hive.account_operations_copyback_method() = 'copy'), it returns once the table is
-- sorted, with hive.account_operations_copyback_state() 'pending'; CALLed again after the caller's
-- copy-back, it goes on with the table's indexes. Must be CALLed outside a transaction block.
CREATE OR REPLACE PROCEDURE hive.proc_restore_indexes( in _table_name TEXT )
LANGUAGE plpgsql
AS
$procedure$
DECLARE
  __command TEXT;
  __rewrite BOOLEAN := FALSE;
  __copied BOOLEAN := FALSE;
  __lock_key BIGINT := hive.index_restore_lock_key( _table_name );
BEGIN
  PERFORM pg_advisory_lock( __lock_key );
  PERFORM hive.reset_interrupted_index_restores( _table_name );
  COMMIT;

  IF _table_name = 'hafd.account_operations' THEN
    __command := hive.missing_account_operations_cluster_index();
    IF __command IS NOT NULL AND hive.account_operations_copyback_state() IS NOT DISTINCT FROM 'copied' THEN
      __copied := TRUE;
    ELSIF hive.account_operations_reorder_method() = 'rewrite' AND __command IS NOT NULL THEN
      __rewrite := hive.account_operations_reorder_space_suffices();
    END IF;

    IF __rewrite AND hive.account_operations_copyback_method() = 'copy' THEN
      RAISE NOTICE 'Reordering hafd.account_operations by (account_id, account_op_seq_no), to be copied back by the caller...';
      CALL hive.proc_stage_and_sort_account_operations();
      RAISE NOTICE 'Leaving the copy-back of the sorted hafd.account_operations to the caller (hive.account_operations_copyback = ''copy'')';
      PERFORM pg_advisory_unlock( __lock_key );
      RETURN;
    END IF;

    IF __rewrite OR __copied THEN
      -- reordered again when interrupted before hive_account_operations_uq1 commits, but for a copied table,
      -- whose steps, recording the copy-back, are dropped after it
      IF __rewrite THEN
        CALL hive.proc_reorder_account_operations();
      END IF;
      -- lets the helpers build the table's plain indexes alongside (hive.is_index_restore_ready)
      PERFORM pg_advisory_xact_lock( hive.account_operations_cluster_index_lock_key() );
      PERFORM hive.restore_index( __command );
      ALTER TABLE hafd.account_operations CLUSTER ON hive_account_operations_uq1;
      COMMIT;
    ELSIF hive.restore_account_operations_cluster_index() THEN
      COMMIT;
      PERFORM hive.cluster_account_operations();
      COMMIT;
    END IF;

    -- only now, in a transaction of its own: dropping the steps locks them, which the helpers read; also
    -- what a restore interrupted after hive_account_operations_uq1 committed left behind
    IF __rewrite OR __copied OR __command IS NULL THEN
      PERFORM hive.drop_account_operations_reorder_tables();
      COMMIT;
    END IF;
  END IF;

  LOOP
    IF hive.restore_next_index( _table_name ) THEN
      COMMIT;
      CONTINUE;
    END IF;
    EXIT WHEN NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints WHERE table_name = _table_name AND is_foreign_key = FALSE AND status = 'missing' );
    -- helpers are building the last indexes
    PERFORM pg_sleep( 1 );
    COMMIT;
  END LOOP;

  EXECUTE format( 'ANALYZE %s',  _table_name );
  COMMIT;

  PERFORM pg_advisory_unlock( __lock_key );
  RAISE NOTICE 'Finished restoring any dropped indexes on %', _table_name;
END;
$procedure$
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
    SELECT consistent_block, is_dirty INTO __consistent_block, __is_dirty FROM hafd.hive_state;

    IF ( __is_dirty = FALSE ) THEN
        RETURN;
    END IF;

    DELETE FROM hafd.account_operations hao
    WHERE hafd.operation_id_to_block_num(hao.operation_id) > __consistent_block;

    DELETE FROM hafd.applied_hardforks WHERE block_num > __consistent_block;

    DELETE FROM hafd.operations WHERE hafd.operation_id_to_block_num(id) > __consistent_block;

    DELETE FROM hafd.transactions_multisig htm
    USING hafd.transactions ht
    WHERE ht.block_num > __consistent_block AND ht.trx_hash = htm.trx_hash;

    DELETE FROM hafd.transactions WHERE block_num > __consistent_block;

    DELETE FROM hafd.accounts WHERE block_num > __consistent_block;

    DELETE FROM hafd.blocks WHERE num > __consistent_block;

    UPDATE hafd.hive_state SET is_dirty = FALSE;
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
        CASE WHEN EXISTS (
            SELECT 1 FROM pg_indexes
            WHERE schemaname = split_part(__table_name, '.', 1)
              AND indexname = __index_name
        ) THEN 'created'::hafd.index_status ELSE 'missing'::hafd.index_status END,
        ARRAY[__context_id]
    )
    ON CONFLICT (table_name, index_constraint_name) DO UPDATE
    SET contexts = array_append(hafd.indexes_constraints.contexts, __context_id)
    WHERE NOT (__context_id = ANY(hafd.indexes_constraints.contexts));
END;
$BODY$
;
/*
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
        RAISE NOTICE 'Sleeping for 10 seconds waiting for indexes to be created';
        PERFORM pg_sleep(10);
    END LOOP;


    __end_time := clock_timestamp();
    __duration := __end_time - __start_time;
    RAISE NOTICE 'Finished waiting for registered indexes to be created for context % in % seconds', _app_context, EXTRACT(EPOCH FROM __duration);
END;
$BODY$
;
*/

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

-- Removes the context from the contexts depending on the index, and drops the index when no context
-- depends on it any more (HAF-internal dependencies are marked as being dependent on context 0 to prevent their removal)
CREATE OR REPLACE FUNCTION hive.remove_index_dependency(
    _context_id INT,
    _table_name TEXT,
    _index_constraint_name TEXT
)
RETURNS void
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __remaining_contexts INT[];
BEGIN
    UPDATE hafd.indexes_constraints
    SET contexts = array_remove(contexts, _context_id)
    WHERE table_name = _table_name AND index_constraint_name = _index_constraint_name
    RETURNING contexts INTO __remaining_contexts;

    IF NOT FOUND OR array_length(__remaining_contexts, 1) IS NOT NULL THEN
        RETURN;
    END IF;

    EXECUTE 'DROP INDEX IF EXISTS ' || split_part(_table_name, '.', 1) || '.' || _index_constraint_name;
    DELETE FROM hafd.indexes_constraints WHERE table_name = _table_name AND index_constraint_name = _index_constraint_name;
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
        PERFORM hive.remove_index_dependency(__context_id, __index_record.table_name, __index_record.index_constraint_name);
    END LOOP;
END;
$BODY$
;

-- _kind: 'full' (VACUUM FULL ANALYZE), 'vacuum' (VACUUM (ANALYZE)), 'analyze' (ANALYZE)
-- or 'freeze' (VACUUM (FREEZE, ANALYZE)). Requests of different kinds for one table are
-- kept separately and hived runs 'full' before the others.
CREATE OR REPLACE FUNCTION hive.app_request_table_vacuum(
    _schema_name TEXT,
    _table_name TEXT,
    _min_interval INTERVAL DEFAULT NULL,
    _kind TEXT DEFAULT 'full'
)
RETURNS void
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    IF _kind IS NULL OR _kind NOT IN ('full', 'vacuum', 'analyze', 'freeze') THEN
        RAISE EXCEPTION 'Invalid vacuum kind %, expected one of: full, vacuum, analyze, freeze', quote_nullable(_kind)
            USING ERRCODE = '22023';
    END IF;

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
            AND kind = _kind
            AND last_vacuumed_time > NOW() - _min_interval
        ) THEN
            -- routine in live sync (applications ask after every block); keep it
            -- out of application logs
            RAISE DEBUG 'Vacuum (%) request for table %.% ignored due to recent vacuum.', _kind, _schema_name, _table_name;
            RETURN;
        END IF;
    END IF;

    -- Insert or update the vacuum request
    INSERT INTO hafd.vacuum_requests (schema_name, table_name, kind, status)
    VALUES (_schema_name, _table_name, _kind, 'requested')
    ON CONFLICT (schema_name, table_name, kind) DO UPDATE
    SET status = 'requested',
        error_message = NULL;

    RAISE NOTICE 'Vacuum (%) request for table %.% submitted.', _kind, _schema_name, _table_name;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_request_table_vacuum(
    _qualified_table_name TEXT,
    _min_interval INTERVAL DEFAULT NULL,
    _kind TEXT DEFAULT 'full'
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

    PERFORM hive.app_request_table_vacuum(_schema_name, _table_name, _min_interval, _kind);
END;
$BODY$
;
/*
CREATE OR REPLACE FUNCTION hive.app_wait_for_table_vacuum(
    _table_name TEXT
)
RETURNS void
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __start_time TIMESTAMP;
    __end_time TIMESTAMP;
    __duration INTERVAL;
BEGIN
    RAISE NOTICE 'Waiting for vacuum to complete for table %', _table_name;
    __start_time := clock_timestamp();

    LOOP
        EXIT WHEN NOT EXISTS (
            SELECT 1
            FROM hafd.vacuum_requests
            WHERE table_name = _table_name
            AND status <> 'vacuumed'            
        );
        RAISE NOTICE 'Sleeping for 1 seconds waiting for vacuum to be done';
        PERFORM pg_sleep(1);
    END LOOP;

    __end_time := clock_timestamp();
    __duration := __end_time - __start_time;
    RAISE NOTICE 'Vacuum completed for table % in % seconds', _table_name, EXTRACT(EPOCH FROM __duration);
END;
$BODY$
;
*/
