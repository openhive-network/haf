
CREATE OR REPLACE FUNCTION hive.copy_blocks_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
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
        hive.blocks_reversible hbr
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
    INSERT INTO hive.transactions
    SELECT
          htr.block_num
        , htr.trx_in_block
        , htr.trx_hash
        , htr.ref_block_num
        , htr.ref_block_prefix
        , htr.expiration
        , htr.signature
    FROM
        hive.transactions_reversible htr
    JOIN ( SELECT
              DISTINCT ON ( hbr.num ) hbr.num
            , hbr.fork_id
            FROM hive.blocks_reversible hbr
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
    INSERT INTO hive.operations
    SELECT
           hor.id
         , hor.trx_in_block
         , hor.op_pos
         , hor.body_binary
    FROM
        hive.operations_reversible hor
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hive.blocks_reversible hbr
            WHERE
                  hbr.num <= _new_irreversible_block
              AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
        ) as num_and_forks ON hive.operation_id_to_block_num_wrapper(hor.id) = num_and_forks.num AND hor.fork_id = num_and_forks.fork_id
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
    INSERT INTO hive.applied_hardforks
    SELECT
           hjr.hardfork_num
         , hjr.block_num
         , hjr.hardfork_vop_id
    FROM
        hive.applied_hardforks_reversible hjr
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hive.blocks_reversible hbr
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
    INSERT INTO hive.transactions_multisig
    SELECT
          tsr.trx_hash
        , tsr.signature
    FROM
        hive.transactions_multisig_reversible tsr
        JOIN hive.transactions_reversible htr ON htr.trx_hash = tsr.trx_hash AND htr.fork_id = tsr.fork_id
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hive.blocks_reversible hbr
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
    INSERT INTO hive.accounts
    SELECT
           har.id
         , har.name
         , har.block_num
    FROM
        hive.accounts_reversible har
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hive.blocks_reversible hbr
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
    INSERT INTO hive.account_operations
    SELECT
           haor.account_id
         , haor.account_op_seq_no
         , haor.operation_id
    FROM
        hive.account_operations_reversible haor
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hive.blocks_reversible hbr
            WHERE
                hbr.num <= _new_irreversible_block
              AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
        ) as num_and_forks ON haor.fork_id = num_and_forks.fork_id AND hive.operation_id_to_block_num_wrapper( haor.operation_id ) = num_and_forks.num
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
    __max_fork_id hive.fork.id%TYPE;
    -- down limit
    __min_ctx_fork_id hive.fork.id%TYPE := hive.max_fork_id();
    __lowest_irreversible_block hive.blocks.num%TYPE := hive.max_block_num();
    __max_block_num hive.blocks.num%TYPE;
BEGIN
    SELECT max(hf.id) INTO __max_fork_id
    FROM hive.fork hf;

    -- can only delete data from  blocks and forks already
    -- consumed by all the context, pair of lowest fork id and
    -- lowest irreversible block is a upper bound of deletion

    SELECT COALESCE( min(hc.fork_id), __min_ctx_fork_id )
         , COALESCE( min(irreversible_block), __lowest_irreversible_block )
    INTO __min_ctx_fork_id, __lowest_irreversible_block
    FROM hive.contexts hc
    WHERE hc.is_attached = TRUE
    AND hc.is_forking = TRUE;

    __max_block_num := LEAST(__lowest_irreversible_block, _new_irreversible_block);

    DELETE FROM hive.account_operations_reversible har
    USING hive.operations_reversible hor
    WHERE
            har.operation_id = hor.id
        AND har.fork_id = hor.fork_id
        AND ( hive.operation_id_to_block_num_wrapper(hor.id) <= __max_block_num OR hor.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id ) )
    ;

    DELETE FROM hive.applied_hardforks_reversible hjr
    WHERE hjr.block_num <= __max_block_num OR hjr.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
    ;

    DELETE FROM hive.operations_reversible hor
    WHERE hive.operation_id_to_block_num_wrapper(hor.id) <= __max_block_num OR hor.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
    ;


    DELETE FROM hive.transactions_multisig_reversible htmr
    USING hive.transactions_reversible htr
    WHERE
            htr.fork_id = htmr.fork_id
        AND htr.trx_hash = htmr.trx_hash
        AND ( htr.block_num <= __max_block_num OR htr.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id ) )
    ;

    DELETE FROM hive.transactions_reversible htr
    WHERE  htr.block_num <= __max_block_num OR htr.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
    ;

    DELETE FROM hive.accounts_reversible har
    WHERE har.block_num <= __max_block_num OR har.fork_id < LEAST( __min_ctx_fork_id, __max_fork_id )
    ;

    DELETE FROM hive.blocks_reversible hbr
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
    -- if we cannot get exclusive lock for contexts row then we return and will back here
    -- next time, when hived will try to remove events with next irreversible block
    -- the contexts are locked by the apps during attach: hive.app_context_attach
    BEGIN
        LOCK TABLE hive.contexts IN ACCESS EXCLUSIVE MODE NOWAIT;
    EXCEPTION WHEN SQLSTATE '55P03' THEN
        -- 55P03 	lock_not_available https://www.postgresql.org/docs/current/errcodes-appendix.html
        RETURN;
    END;


    SELECT consistent_block INTO __max_block_num FROM hive.irreversible_data;

    -- find the upper bound of events possible to remove
    SELECT MIN(heq.id) INTO __upper_bound_events_id
    FROM hive.events_queue heq
    WHERE heq.event != 'BACK_FROM_FORK' AND heq.block_num = ( _new_irreversible_block + 1 ); --next block after irreversible

    -- You may think that SELECT FOR UPDATE needs to be used here in USING clause
    -- but SELECT FOR UPDATE will lock hive.contexts, so it want to acquire lock
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

    DELETE FROM hive.events_queue heq
    USING ( SELECT MIN( hc.events_id) as id FROM hive.contexts hc ) as min_event
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
    INSERT INTO hive.indexes_constraints( index_constraint_name, table_name, command, is_constraint, is_index, is_foreign_key )
    SELECT
        T.indexname
      , _schema || '.' || _table
      , T.indexdef
      , FALSE as is_constraint
      , TRUE as is_index
      , FALSE as is_foreign_key
    FROM
    (
      SELECT indexname, indexdef
      FROM pg_indexes
      WHERE schemaname = _schema AND tablename = _table
    ) T LEFT JOIN hive.indexes_constraints ic ON( T.indexname = ic.index_constraint_name )
    WHERE ic.table_name is NULL
    ON CONFLICT DO NOTHING;

    --dropping indexes
    OPEN __cursor FOR (
        SELECT ('DROP INDEX IF EXISTS '::TEXT || _schema || '.' || index_constraint_name || ';')
        FROM hive.indexes_constraints WHERE table_name = _schema || '.' || _table AND is_index = TRUE
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
        FROM hive.indexes_constraints WHERE table_name = _schema || '.' || _table AND is_constraint = TRUE
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

CREATE OR REPLACE FUNCTION hive.save_and_drop_indexes_foreign_keys( in _table_schema TEXT, in _table_name TEXT )
RETURNS VOID
AS
$function$
DECLARE
    __command TEXT;
    __cursor REFCURSOR;
BEGIN
    INSERT INTO hive.indexes_constraints( index_constraint_name, table_name, command, is_constraint, is_index, is_foreign_key )
    SELECT
          DISTINCT ON ( pgc.conname ) pgc.conname as constraint_name
        , _table_schema || '.' || _table_name as table_name
        , 'ALTER TABLE ' || tc.table_schema || '.' || tc.table_name || ' ADD CONSTRAINT ' || pgc.conname || ' ' || pg_get_constraintdef(pgc.oid) as command
        , FALSE as is_constraint
        , FALSE AS is_index
        , TRUE as is_foreign_key
    FROM pg_constraint pgc
    JOIN pg_namespace nsp on nsp.oid = pgc.connamespace
    JOIN information_schema.table_constraints tc ON pgc.conname = tc.constraint_name AND nsp.nspname = tc.constraint_schema
    WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = _table_schema AND tc.table_name = _table_name;

    OPEN __cursor FOR (
        SELECT ('ALTER TABLE '::TEXT || _table_schema || '.' || _table_name || ' DROP CONSTRAINT IF EXISTS ' || index_constraint_name || ';')
        FROM hive.indexes_constraints WHERE table_name = ( _table_schema || '.' || _table_name ) AND is_foreign_key = TRUE
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
    INSERT INTO hive.indexes_constraints( index_constraint_name, table_name, command, is_constraint, is_index, is_foreign_key )
    SELECT
        DISTINCT ON ( pgc.conname ) pgc.conname as constraint_name
        , _table_schema || '.' || _table_name as table_name
        , 'ALTER TABLE ' || tc.table_schema || '.' || tc.table_name || ' ADD CONSTRAINT ' || pgc.conname || ' ' || pg_get_constraintdef(pgc.oid) as command
        , tc.constraint_type = 'PRIMARY KEY' OR tc.constraint_type = 'UNIQUE' as is_constraint
        , FALSE AS is_index
        , FALSE as is_foreign_key
    FROM pg_constraint pgc
        JOIN pg_namespace nsp on nsp.oid = pgc.connamespace
        JOIN information_schema.table_constraints tc ON pgc.conname = tc.constraint_name AND nsp.nspname = tc.constraint_schema
    WHERE tc.constraint_type != 'FOREIGN KEY' AND tc.table_schema = _table_schema AND tc.table_name = _table_name;

    OPEN __cursor FOR (
            SELECT ('ALTER TABLE '::TEXT || _table_schema || '.' || _table_name || ' DROP CONSTRAINT IF EXISTS ' || index_constraint_name || ';')
            FROM hive.indexes_constraints WHERE table_name = ( _table_schema || '.' || _table_name ) AND is_foreign_key = TRUE
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
                SELECT command FROM hive.indexes_constraints 
                WHERE table_name = 'hive.account_operations' AND
                      index_constraint_name = 'hive_account_operations_uq1' LIMIT 1);
  IF (__cluster_index_dropped) THEN
    RAISE NOTICE 'Cluster index dropped, restoring it before other indexes for faster clustering';
    SELECT command INTO __command FROM hive.indexes_constraints
    WHERE table_name = 'hive.account_operations' AND
          index_constraint_name = 'hive_account_operations_uq1' LIMIT 1;      
    EXECUTE __command;
    RAISE NOTICE 'Clustering hive.account_operations, this takes a while...';
    CLUSTER hive.account_operations using hive_account_operations_uq1;
    RAISE NOTICE 'Analyzing hive.account_operations after clustering to update statistics';
    ANALYZE hive.account_operations;
    DELETE FROM hive.indexes_constraints WHERE command = __command;
  END IF;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.restore_indexes( in _table_name TEXT )
RETURNS VOID
AS
$function$
DECLARE
  __command TEXT;
  __cursor REFCURSOR;
BEGIN

  IF _table_name = 'hive.account_operations' THEN
    PERFORM hive.recluster_account_operations_if_index_dropped();
  END IF;

  --restoring indexes, primary keys, unique contraints
  OPEN __cursor FOR ( SELECT command FROM hive.indexes_constraints WHERE table_name = _table_name AND is_foreign_key = FALSE );
  LOOP
    FETCH __cursor INTO __command;
    EXIT WHEN NOT FOUND;
    EXECUTE __command;
  END LOOP;
  CLOSE __cursor;

  DELETE FROM hive.indexes_constraints
  WHERE table_name = _table_name AND is_foreign_key = FALSE;
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

    --restoring indexes, primary keys, unique contraints
    OPEN __cursor FOR ( SELECT command FROM hive.indexes_constraints WHERE table_name = _table_name AND is_foreign_key = TRUE );
    LOOP
    FETCH __cursor INTO __command;
        EXIT WHEN NOT FOUND;
        EXECUTE __command;
    END LOOP;
    CLOSE __cursor;

    DELETE FROM hive.indexes_constraints
    WHERE table_name = _table_name AND is_foreign_key = TRUE;

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
    SELECT consistent_block, is_dirty INTO __consistent_block, __is_dirty FROM hive.irreversible_data;

    IF ( __is_dirty = FALSE ) THEN
        RETURN;
    END IF;

    DELETE FROM hive.account_operations hao
    WHERE hive.operation_id_to_block_num_wrapper(hao.operation_id) > __consistent_block;

    DELETE FROM hive.applied_hardforks WHERE block_num > __consistent_block;

    DELETE FROM hive.operations WHERE hive.operation_id_to_block_num_wrapper(id) > __consistent_block;

    DELETE FROM hive.transactions_multisig htm
    USING hive.transactions ht
    WHERE ht.block_num > __consistent_block AND ht.trx_hash = htm.trx_hash;

    DELETE FROM hive.transactions WHERE block_num > __consistent_block;

    DELETE FROM hive.accounts WHERE block_num > __consistent_block;

    DELETE FROM hive.blocks WHERE num > __consistent_block;

    UPDATE hive.irreversible_data SET is_dirty = FALSE;
END;
$BODY$
;
