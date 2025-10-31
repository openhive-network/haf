CREATE OR REPLACE FUNCTION hive.reanalyze_indexes_with_expressions()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- put here analyze for tables which indexes are using expressions
    -- the function is called after hfm creates/drops indexes
    -- without this statistics for expressions won't exists and planner
    -- will choose wrongly execution plans

    ANALYZE hafd.operations;
    ANALYZE hafd.operations_reversible;
    ANALYZE hafd.account_operations;
    ANALYZE hafd.account_operations_reversible;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.back_from_fork( _block_num_before_fork INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __fork_id BIGINT;
BEGIN
    INSERT INTO hafd.fork(block_num, time_of_fork)
    VALUES( _block_num_before_fork, LOCALTIMESTAMP );

    SELECT MAX(hf.id) INTO __fork_id FROM hafd.fork hf;
    INSERT INTO hafd.events_queue( event, block_num )
    VALUES( 'BACK_FROM_FORK', __fork_id );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.push_block(
      _block hafd.blocks
    , _transactions hafd.transactions[]
    , _signatures hafd.transactions_multisig[]
    , _operations hafd.operations[]
    , _accounts hafd.accounts[]
    , _account_operations hafd.account_operations[]
    , _applied_hardforks hafd.applied_hardforks[]
)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __fork_id hafd.fork.id%TYPE;
BEGIN
    SELECT hf.id
    INTO __fork_id
    FROM hafd.fork hf ORDER BY hf.id DESC LIMIT 1;

    INSERT INTO hafd.events_queue( event, block_num )
        VALUES( 'NEW_BLOCK', _block.num );

    INSERT INTO hafd.blocks_reversible VALUES( _block.*, __fork_id );
    INSERT INTO hafd.transactions_reversible VALUES( ( unnest( _transactions ) ).*, __fork_id );
    INSERT INTO hafd.transactions_multisig_reversible VALUES( ( unnest( _signatures ) ).*, __fork_id );
    INSERT INTO hafd.operations_reversible(id, trx_in_block, op_pos, body_binary, fork_id)
      SELECT id, trx_in_block, op_pos, body_binary, __fork_id FROM unnest( _operations );
    INSERT INTO hafd.accounts_reversible VALUES( ( unnest( _accounts ) ).*, __fork_id );
    INSERT INTO hafd.account_operations_reversible VALUES( ( unnest( _account_operations ) ).*, __fork_id );
    INSERT INTO hafd.applied_hardforks_reversible VALUES( ( unnest( _applied_hardforks ) ).*, __fork_id );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.set_irreversible( _block_num INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __irreversible_head_block hafd.blocks.num%TYPE;
BEGIN
    SELECT COALESCE( MAX( num ), 0 ) INTO __irreversible_head_block FROM hafd.blocks;

    IF ( _block_num < __irreversible_head_block ) THEN
        RETURN;
    END IF;

    -- copy to irreversible
    PERFORM hive.copy_blocks_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_transactions_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_operations_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_signatures_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_accounts_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_account_operations_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_applied_hardforks_to_irreversible( __irreversible_head_block, _block_num );

    -- if we cannot get exclusive lock for contexts row then we return and will back here
    -- next time, when hived will try to remove blocks with next irreversible block
    -- the contexts are locked by the apps during attach: hive.app_context_attach
    BEGIN
        LOCK TABLE hafd.contexts_attachment IN EXCLUSIVE MODE NOWAIT;
        PERFORM hive.remove_unecessary_events( _block_num );
        -- remove unneeded blocks and events
        PERFORM hive.remove_obsolete_reversible_data( _block_num );
    EXCEPTION WHEN SQLSTATE '55P03' THEN
        -- 55P03 	lock_not_available https://www.postgresql.org/docs/current/errcodes-appendix.html
    END;


    -- application contexts will use the event to clear data in shadow tables
    INSERT INTO hafd.events_queue( event, block_num )
    VALUES( 'NEW_IRREVERSIBLE', _block_num );
    UPDATE hafd.hive_state SET consistent_block = _block_num;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.end_massive_sync( _block_num INTEGER )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- if we cannot get exclusive lock for contexts row then we return and will back here
    -- next time, when hived will try to remove blocks with next irreversible block
    -- the contexts are locked by the apps during attach: hive.app_context_attach
    BEGIN
     -- remove all events less than lowest context events_id
        LOCK TABLE hafd.contexts_attachment IN EXCLUSIVE MODE NOWAIT;
        PERFORM hive.remove_unecessary_events( _block_num );
        PERFORM hive.remove_obsolete_reversible_data( _block_num );
    EXCEPTION WHEN SQLSTATE '55P03' THEN
        -- 55P03 	lock_not_available https://www.postgresql.org/docs/current/errcodes-appendix.html
    END;

    INSERT INTO hafd.events_queue( event, block_num )
    VALUES ( 'MASSIVE_SYNC'::hafd.event_type, _block_num );

    UPDATE hafd.hive_state SET consistent_block = _block_num;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.set_irreversible_dirty()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    UPDATE hafd.hive_state SET is_dirty = TRUE;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.set_irreversible_not_dirty()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    UPDATE hafd.hive_state SET is_dirty = FALSE;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.is_irreversible_dirty()
    RETURNS BOOL
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __is_dirty BOOL := FALSE;
BEGIN
    SELECT is_dirty INTO __is_dirty FROM hafd.hive_state;
    RETURN __is_dirty;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.disable_indexes_of_irreversible()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    IF hive.is_pruning_enabled() = TRUE THEN
       RETURN;
    END IF;

    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'blocks' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'transactions' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'transactions_multisig' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'operations' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'applied_hardforks' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'accounts' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'account_operations' );

    PERFORM hive.reanalyze_indexes_with_expressions(); --I wonder if reanalyzing is really needed when indexes are dropped
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.disable_fk_of_irreversible()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'hive_state' );
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'blocks' );
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'transactions' );
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'transactions_multisig' );
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'operations' );
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'applied_hardforks' );
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'accounts' );
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'account_operations' );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.enable_indexes_of_irreversible()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.restore_indexes( 'hafd.blocks' );
    PERFORM hive.restore_indexes( 'hafd.transactions' );
    PERFORM hive.restore_indexes( 'hafd.transactions_multisig' );
    PERFORM hive.restore_indexes( 'hafd.operations' );
    PERFORM hive.restore_indexes( 'hafd.applied_hardforks' );
    PERFORM hive.restore_indexes( 'hafd.accounts' );
    PERFORM hive.restore_indexes( 'hafd.account_operations' );
    PERFORM hive.restore_indexes( 'hafd.hive_state' );

    PERFORM hive.reanalyze_indexes_with_expressions();
END;
$BODY$
SET maintenance_work_mem TO '6GB';
;

CREATE OR REPLACE FUNCTION hive.enable_fk_of_irreversible()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.restore_foreign_keys( 'hafd.blocks' );
    PERFORM hive.restore_foreign_keys( 'hafd.transactions' );
    PERFORM hive.restore_foreign_keys( 'hafd.transactions_multisig' );
    PERFORM hive.restore_foreign_keys( 'hafd.operations' );
    PERFORM hive.restore_foreign_keys( 'hafd.applied_hardforks' );
    PERFORM hive.restore_foreign_keys( 'hafd.hive_state' );
    PERFORM hive.restore_foreign_keys( 'hafd.accounts' );
    PERFORM hive.restore_foreign_keys( 'hafd.account_operations' );

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.disable_indexes_of_reversible()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'blocks_reversible' );
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'transactions_reversible' );
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'transactions_multisig_reversible' );
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'operations_reversible' );
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'applied_hardforks_reversible' );
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'accounts_reversible' );
    PERFORM hive.save_and_drop_foreign_keys( 'hafd', 'account_operations_reversible' );



    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'blocks_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'transactions_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'transactions_multisig_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'operations_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'applied_hardforks_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'accounts_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hafd', 'account_operations_reversible' );

    PERFORM hive.reanalyze_indexes_with_expressions(); --I wonder if reanalyzing is really needed when indexes are dropped

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.enable_indexes_of_reversible()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.restore_indexes( 'hafd.blocks_reversible' );
    PERFORM hive.restore_indexes( 'hafd.transactions_reversible' );
    PERFORM hive.restore_indexes( 'hafd.transactions_multisig_reversible' );
    PERFORM hive.restore_indexes( 'hafd.operations_reversible' );
    PERFORM hive.restore_indexes( 'hafd.accounts_reversible' );
    PERFORM hive.restore_indexes( 'hafd.account_operations_reversible' );
    PERFORM hive.restore_indexes( 'hafd.applied_hardforks_reversible' );



    PERFORM hive.restore_foreign_keys( 'hafd.blocks_reversible' );
    PERFORM hive.restore_foreign_keys( 'hafd.transactions_reversible' );
    PERFORM hive.restore_foreign_keys( 'hafd.transactions_multisig_reversible' );
    PERFORM hive.restore_foreign_keys( 'hafd.operations_reversible' );
    PERFORM hive.restore_foreign_keys( 'hafd.accounts_reversible' );
    PERFORM hive.restore_foreign_keys( 'hafd.account_operations_reversible' );
    PERFORM hive.restore_foreign_keys( 'hafd.applied_hardforks_reversible' );

    PERFORM hive.reanalyze_indexes_with_expressions();
END;
$BODY$
;



CREATE OR REPLACE FUNCTION hive.connect( _git_sha TEXT, _block_num hafd.blocks.num%TYPE, _first_block hafd.blocks.num%TYPE, _pruning integer )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __max_block hafd.blocks.num%TYPE;
    __last_pruning integer;
BEGIN
    -- assumptions:
    -- sql-serializer WAL was replayed after (re)start
    -- at the moment of call hived finished restarting and did removing reversible data from state if it was desire
    PERFORM hive.remove_inconsistent_irreversible_data();
    SELECT MAX(num) INTO __max_block FROM hive.blocks_view;
    -- we need remove with fork event blocks which are greater than head block in hived state(param _block_num)
    -- because WAL was replayed, we are sure that we have situation before hived close
    -- when hived did remove reversible data than we have two possibilities:
    --  1. max(block_num) in HAF is greater than HB in state, lacking blocks are going to replay and HAF must prepare a new fork for them
    --  2. max(block_num) in HAF is equal HB in state, newly replayed blocks will be new for HAF, no fork required
    ASSERT COALESCE(__max_block,0) >= _block_num OR COALESCE(__max_block,0) < _first_block, 'Hived state cannot have more blocks on top micro fork than HAF';
    -- when hived did not remove reversible data (i.e. is during reply) the situation is the same as for point 2 above -> no fork is required
    IF __max_block > _block_num OR _block_num = 0 THEN --_block_num = 0 to ensure that at least 1 fork exists
        PERFORM hive.back_from_fork( _block_num );
    END IF;

    INSERT INTO hafd.hived_connections( block_num, git_sha, time )
    VALUES( _block_num, _git_sha, now() );

    ASSERT ( hive.is_pruning_enabled() = FALSE OR ( hive.is_pruning_enabled() = TRUE AND _pruning > 0 ) )
           , 'Cannot initialize as non‑pruned: existing database is pruned. Drop/recreate the database or run in pruned mode.';

    UPDATE hafd.hive_stable_state
    SET pruning = _pruning;

    IF hive.is_pruning_enabled() = TRUE THEN
        -- we need to drop FK to fast remove from hafd.operations
        -- because it is impossible to back from pruned to non-pruned we do not bother with FK recreations
        ALTER TABLE hafd.account_operations DROP CONSTRAINT IF EXISTS hive_account_operations_fk_2;
    END IF;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.all_indexes_have_status(_status hafd.index_status)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    _all_indices_have_status BOOLEAN;
    record hafd.indexes_constraints%ROWTYPE;
BEGIN
    -- Debugging: Log the current state of the indexes_constraints table
    RAISE NOTICE 'Current state of hafd.indexes_constraints:';
    FOR record IN
        SELECT * FROM hafd.indexes_constraints
    LOOP
        RAISE NOTICE 'index_constraint_name: %, table_name: %, status: %', record.index_constraint_name, record.table_name, record.status;
    END LOOP;

    SELECT bool_and(status=_status)
    INTO _all_indices_have_status
    FROM hafd.indexes_constraints;

    RETURN _all_indices_have_status;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.are_any_indexes_missing()
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __number_of_dropped_indexes INT;
BEGIN
    SELECT COUNT(*) FROM hafd.indexes_constraints
    WHERE is_index AND status = 'missing'
    INTO __number_of_dropped_indexes;
    IF ( __number_of_dropped_indexes = 0 ) THEN
        RETURN FALSE;
    ELSE
        RETURN TRUE;
    END IF;
 
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.are_indexes_restored()
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
  RETURN COALESCE(hive.all_indexes_have_status('created'), TRUE);
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.are_fk_dropped()
    RETURNS BOOL
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __a_fk_exists INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO __a_fk_exists
    FROM hafd.indexes_constraints
    WHERE is_foreign_key AND status != 'missing';

    RETURN __a_fk_exists = 0;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.initialize_extension_data()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __events_id BIGINT := 0;
BEGIN
    IF EXISTS ( SELECT 1 FROM hafd.events_queue WHERE id = hive.unreachable_event_id() LIMIT 1 ) THEN
        SELECT MAX(eq.id) + 1 FROM hafd.events_queue eq WHERE eq.id != hive.unreachable_event_id() INTO __events_id;
        PERFORM SETVAL( 'hafd.events_queue_id_seq', __events_id, false );
        -- PERFORM hive_update.create_database_hash();
        RETURN;
    END IF;

    INSERT INTO hafd.hive_state VALUES(1,NULL, FALSE) ON CONFLICT DO NOTHING;
    INSERT INTO hafd.hive_stable_state VALUES(1,0) ON CONFLICT DO NOTHING;
    INSERT INTO hafd.events_queue VALUES( 0, 'NEW_IRREVERSIBLE', 0 ) ON CONFLICT DO NOTHING;
    INSERT INTO hafd.events_queue VALUES( hive.unreachable_event_id(), 'NEW_BLOCK', 2147483647 ) ON CONFLICT DO NOTHING;
    SELECT MAX(eq.id) + 1 FROM hafd.events_queue eq WHERE eq.id != hive.unreachable_event_id() INTO __events_id;
    PERFORM SETVAL( 'hafd.events_queue_id_seq', __events_id, false );

    INSERT INTO hafd.fork(block_num, time_of_fork) VALUES( 1, '2016-03-24 16:05:00'::timestamp ) ON CONFLICT DO NOTHING;

    -- if contexts are created before starting hived
    UPDATE hafd.contexts hc
    SET fork_id = 1, events_id = 0
    FROM hafd.contexts_attachment  hac
    WHERE hac.context_id = hc.id
    AND hac.is_attached = TRUE;

    UPDATE hafd.contexts hc
    SET fork_id = 1, events_id = hive.unreachable_event_id()
    FROM hafd.contexts_attachment  hac
    WHERE hac.context_id = hc.id
    AND hac.is_attached = FALSE;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_wal_sequence_number(_new_sequence_number INTEGER)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hafd.write_ahead_log_state VALUES (1, _new_sequence_number)
    ON CONFLICT (id) DO UPDATE SET last_sequence_number_committed = _new_sequence_number WHERE hafd.write_ahead_log_state.id = 1;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_wal_sequence_number()
    RETURNS INTEGER
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __last_sequence_number_committed INT;
BEGIN
    SELECT last_sequence_number_committed FROM hafd.write_ahead_log_state WHERE id = 1 INTO __last_sequence_number_committed;
    return __last_sequence_number_committed;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE hive.proc_perform_dead_app_contexts_auto_detach( IN _app_timeout INTERVAL DEFAULT '4 hours'::INTERVAL )
    LANGUAGE plpgsql
AS
$BODY$
DECLARE
  __contexts hafd.context_name[];
  __ctx TEXT;
  __now TIMESTAMP WITHOUT TIME ZONE := NOW();
  __current_block_before_detach INT;
BEGIN
  IF NOT hive.is_instance_ready() THEN
    RAISE WARNING 'Skipping auto detach, because HAF is not in live mode';
    RETURN;
  END IF;

    -- first we take lock to attachment rows for only outdated contexts
    -- because we have idle_in_transaction_session_timeout = 1h, we are sure that
    -- 1) broken app transaction are closed (no locks are made by the context)
    -- 2) application is still pending and may hold locks for attachments rows
    -- ad1) detach the context, it is broken, un working application
    -- ad2) it did not commit during last 4 hours, but still executing some query
        -- stay it attached, it is possible that the app was waiting for HAF to start
        -- problem: such apps may be mixed with 1st kind apps
    -- we cannot stop here because someone holds locks, so SKIP LOCKED is used

  SELECT ARRAY_AGG(ctxs.name) INTO __contexts FROM (
    SELECT c.name
    FROM hafd.contexts c
    JOIN hafd.contexts_attachment hca ON hca.context_id = c.id
    WHERE hca.is_attached
      AND c.last_active_at < __now - _app_timeout FOR UPDATE SKIP LOCKED
  ) as ctxs;

  IF CARDINALITY(__contexts) != 0 THEN
    RAISE WARNING 'Attempting to automatically detach application contexts: %', __contexts;

    FOREACH __ctx IN ARRAY __contexts
    LOOP
      BEGIN
      RAISE WARNING 'Attempting to automatically detach application context: %', __ctx;
      SELECT hc.current_block_num INTO __current_block_before_detach
      FROM hafd.contexts hc WHERE hc.name = __ctx;
      PERFORM hive.app_context_detach(__ctx);
      -- Detach functionality is specifically designed for use within the application's main loop.
      -- It automatically steps back by one block, which is previously incremented by 'app_next_block.'
      -- This design removes from applications obligation managing the 'current_block' explicitly.
      -- However, it's crucial to note that auto-detach is initiated outside the main application loop,
      -- and as such, it must refrain from modifying the 'current_block.', otherwise
      -- it can lead to scenarios where re-attached applications will process
      -- the same block twice after being auto-detached and subsequently restarted.
      -- there is no need to update block num of applications which are using stages and new loop
      -- they have stored all information in their state and they will update attachment in the next_loop_iteration procedure
      -- the only problem is with app_next_block which is executed by the iteration, but the lock taken here
      -- on the function beginning ensures the iteration loop work consistent

      UPDATE hafd.contexts
      SET current_block_num = __current_block_before_detach
      WHERE name = __ctx AND stages IS NULL;
      RAISE WARNING 'Done automatic detaching of application context: %', __ctx;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE WARNING 'FAILED automatic detaching of application context: %', __ctx;
      END;
    END LOOP;
  END IF;
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.get_sync_state()
    RETURNS hafd.sync_state
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result hafd.sync_state;
BEGIN
    SELECT state INTO __result
    FROM hafd.hive_state;

    RETURN __result;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.set_sync_state( _new_state hafd.sync_state )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    UPDATE hafd.hive_state SET state = _new_state;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_vacuum_full_commands(schema_name TEXT DEFAULT 'hafd')
RETURNS SETOF TEXT
LANGUAGE sql
AS $$
    SELECT format('VACUUM FULL %I.%I;', schemaname, tablename) as vacuum_cmd
    FROM pg_tables
    WHERE schemaname = schema_name;
$$;
