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

-- Rewrites hafd.account_operations in (account_id, account_op_seq_no) order, keeping the table
-- itself (its OID, row type, grants, views, triggers and extension membership), and commits after
-- every step but the last, so that only the last one holds back the vacuum horizon for long:
-- 1. the heap is copied, _pages_per_step pages per transaction, into unlogged staging partitions,
--    each a range of account_id holding about _pages_per_step pages of rows, the bounds taken from
--    a sample of the table;
-- 2. each partition is sorted into an unlogged table of its own, one transaction each;
-- 3. one transaction truncates hafd.account_operations and appends the sorted tables to it in
--    account_id order: a sequential copy, without the sort CLUSTER does in its single statement.
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
  __buckets INTEGER;
  __bounds INTEGER[];
  __page BIGINT := 0;
  __staged BIGINT := 0;
  __copied BIGINT := 0;
  __rows BIGINT;
  __bucket INTEGER;
  __start_time TIMESTAMP := clock_timestamp();
  __step_time TIMESTAMP;
BEGIN
  IF _pages_per_step < 1 THEN
    RAISE EXCEPTION '_pages_per_step must be positive, not %', _pages_per_step;
  END IF;

  RAISE NOTICE 'Reordering hafd.account_operations by (account_id, account_op_seq_no)...';
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
  COMMIT;

  __step_time := clock_timestamp();
  WHILE __page < __pages LOOP
    INSERT INTO hafd.account_operations_reorder_staging
    SELECT * FROM hafd.account_operations
    WHERE ctid >= format( '(%s,0)', __page )::TID AND ctid < format( '(%s,0)', __page + _pages_per_step )::TID;
    GET DIAGNOSTICS __rows = ROW_COUNT;
    __staged := __staged + __rows;
    COMMIT;
    __page := __page + _pages_per_step;
  END LOOP;
  RAISE NOTICE 'Staged % rows of hafd.account_operations into % account ranges in % seconds'
    , __staged, cardinality( __bounds ) + 1, EXTRACT( EPOCH FROM clock_timestamp() - __step_time );

  __step_time := clock_timestamp();
  FOR __bucket IN 0 .. cardinality( __bounds ) LOOP
    EXECUTE format( 'CREATE UNLOGGED TABLE hafd.%I AS SELECT * FROM hafd.%I ORDER BY account_id, account_op_seq_no'
      , 'account_operations_reorder_sorted_' || __bucket, 'account_operations_reorder_part_' || __bucket );
    EXECUTE format( 'DROP TABLE hafd.%I', 'account_operations_reorder_part_' || __bucket );
    COMMIT;
  END LOOP;
  RAISE NOTICE 'Sorted the account ranges of hafd.account_operations in % seconds', EXTRACT( EPOCH FROM clock_timestamp() - __step_time );

  __step_time := clock_timestamp();
  LOCK TABLE hafd.account_operations IN ACCESS EXCLUSIVE MODE;
  IF pg_relation_size( 'hafd.account_operations' ) / current_setting( 'block_size' )::BIGINT <> __pages THEN
    RAISE EXCEPTION 'hafd.account_operations changed while it was being reordered';
  END IF;
  -- a synchronized scan could start in the middle of a sorted table
  PERFORM set_config( 'synchronize_seqscans', 'off', TRUE );
  TRUNCATE hafd.account_operations;
  FOR __bucket IN 0 .. cardinality( __bounds ) LOOP
    EXECUTE format( 'INSERT INTO hafd.account_operations SELECT * FROM hafd.%I', 'account_operations_reorder_sorted_' || __bucket );
    GET DIAGNOSTICS __rows = ROW_COUNT;
    __copied := __copied + __rows;
  END LOOP;
  IF __copied <> __staged THEN
    RAISE EXCEPTION 'Reordering hafd.account_operations staged % rows but copied %', __staged, __copied;
  END IF;
  PERFORM hive.drop_account_operations_reorder_tables();
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

-- Restores the table's indexes and PK/UNIQUE constraints in the caller's transaction.
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

-- hive.restore_indexes, committing after each index build, the reorder of hafd.account_operations
-- and the ANALYZE, so a restore holds back the vacuum horizon only for the statement that is running,
-- not for the whole table. hafd.account_operations is reordered as hive.account_operations_reorder_method
-- says. Must be CALLed outside a transaction block.
CREATE OR REPLACE PROCEDURE hive.proc_restore_indexes( in _table_name TEXT )
LANGUAGE plpgsql
AS
$procedure$
DECLARE
  __command TEXT;
BEGIN
  PERFORM hive.reset_interrupted_index_restores( _table_name );
  COMMIT;

  IF _table_name = 'hafd.account_operations' THEN
    IF hive.account_operations_reorder_method() = 'cluster' THEN
      IF hive.restore_account_operations_cluster_index() THEN
        COMMIT;
        PERFORM hive.cluster_account_operations();
        COMMIT;
      END IF;
    ELSE
      __command := hive.missing_account_operations_cluster_index();
      IF __command IS NOT NULL THEN
        -- reordered again when interrupted before hive_account_operations_uq1 commits
        CALL hive.proc_reorder_account_operations();
        PERFORM hive.restore_index( __command );
        ALTER TABLE hafd.account_operations CLUSTER ON hive_account_operations_uq1;
        COMMIT;
      END IF;
    END IF;
  END IF;

  FOR __command IN
    SELECT command FROM hafd.indexes_constraints WHERE table_name = _table_name AND is_foreign_key = FALSE AND status = 'missing'
  LOOP
    PERFORM hive.restore_index( __command );
    COMMIT;
  END LOOP;

  EXECUTE format( 'ANALYZE %s',  _table_name );
  COMMIT;

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
