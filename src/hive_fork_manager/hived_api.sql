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

    ANALYZE hive.operations;
    ANALYZE hive.operations_reversible;
    ANALYZE hive.account_operations;
    ANALYZE hive.account_operations_reversible;
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
    INSERT INTO hive.fork(block_num, time_of_fork)
    VALUES( _block_num_before_fork, LOCALTIMESTAMP );

    SELECT MAX(hf.id) INTO __fork_id FROM hive.fork hf;
    INSERT INTO hive.events_queue( event, block_num )
    VALUES( 'BACK_FROM_FORK', __fork_id );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.push_block(
      _block hive.blocks
    , _transactions hive.transactions[]
    , _signatures hive.transactions_multisig[]
    , _operations hive.operations[]
    , _accounts hive.accounts[]
    , _account_operations hive.account_operations[]
    , _applied_hardforks hive.applied_hardforks[]
)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __fork_id hive.fork.id%TYPE;
BEGIN
    SELECT hf.id
    INTO __fork_id
    FROM hive.fork hf ORDER BY hf.id DESC LIMIT 1;

    INSERT INTO hive.events_queue( event, block_num )
        VALUES( 'NEW_BLOCK', _block.num );

    INSERT INTO hive.blocks_reversible VALUES( _block.*, __fork_id );
    INSERT INTO hive.transactions_reversible VALUES( ( unnest( _transactions ) ).*, __fork_id );
    INSERT INTO hive.transactions_multisig_reversible VALUES( ( unnest( _signatures ) ).*, __fork_id );
    INSERT INTO hive.operations_reversible(id, trx_in_block, op_pos, timestamp, body_binary, fork_id)
      SELECT id, trx_in_block, op_pos, timestamp, body_binary, __fork_id FROM unnest( _operations );
    INSERT INTO hive.accounts_reversible VALUES( ( unnest( _accounts ) ).*, __fork_id );
    INSERT INTO hive.account_operations_reversible VALUES( ( unnest( _account_operations ) ).*, __fork_id );
    INSERT INTO hive.applied_hardforks_reversible VALUES( ( unnest( _applied_hardforks ) ).*, __fork_id );
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
    __irreversible_head_block hive.blocks.num%TYPE;
BEGIN
    SELECT COALESCE( MAX( num ), 0 ) INTO __irreversible_head_block FROM hive.blocks;

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
        LOCK TABLE hive.contexts IN ACCESS EXCLUSIVE MODE NOWAIT;
        PERFORM hive.remove_unecessary_events( _block_num );
        -- remove unneeded blocks and events
        PERFORM hive.remove_obsolete_reversible_data( _block_num );
    EXCEPTION WHEN SQLSTATE '55P03' THEN
        -- 55P03 	lock_not_available https://www.postgresql.org/docs/current/errcodes-appendix.html
    END;


    -- application contexts will use the event to clear data in shadow tables
    INSERT INTO hive.events_queue( event, block_num )
    VALUES( 'NEW_IRREVERSIBLE', _block_num );
    UPDATE hive.irreversible_data SET consistent_block = _block_num;
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
        PERFORM hive.remove_unecessary_events( _block_num );
        PERFORM hive.remove_obsolete_reversible_data( _block_num );
    EXCEPTION WHEN SQLSTATE '55P03' THEN
        -- 55P03 	lock_not_available https://www.postgresql.org/docs/current/errcodes-appendix.html
    END;

    INSERT INTO hive.events_queue( event, block_num )
    VALUES ( 'MASSIVE_SYNC'::hive.event_type, _block_num );



    UPDATE hive.irreversible_data SET consistent_block = _block_num;
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
    UPDATE hive.irreversible_data SET is_dirty = TRUE;
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
    UPDATE hive.irreversible_data SET is_dirty = FALSE;
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
    SELECT is_dirty INTO __is_dirty FROM hive.irreversible_data;
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
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'blocks' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'transactions' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'transactions_multisig' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'operations' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'applied_hardforks' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'accounts' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'account_operations' );

    PERFORM hive.reanalyze_indexes_with_expressions();
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
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'irreversible_data' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'blocks' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'transactions' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'transactions_multisig' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'operations' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'applied_hardforks' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'accounts' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'account_operations' );

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
    PERFORM hive.restore_indexes( 'hive.blocks' );
    PERFORM hive.restore_indexes( 'hive.transactions' );
    PERFORM hive.restore_indexes( 'hive.transactions_multisig' );
    PERFORM hive.restore_indexes( 'hive.operations' );
    PERFORM hive.restore_indexes( 'hive.applied_hardforks' );
    PERFORM hive.restore_indexes( 'hive.accounts' );
    PERFORM hive.restore_indexes( 'hive.account_operations' );
    PERFORM hive.restore_indexes( 'hive.irreversible_data' );

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
    PERFORM hive.restore_foreign_keys( 'hive.blocks' );
    PERFORM hive.restore_foreign_keys( 'hive.transactions' );
    PERFORM hive.restore_foreign_keys( 'hive.transactions_multisig' );
    PERFORM hive.restore_foreign_keys( 'hive.operations' );
    PERFORM hive.restore_foreign_keys( 'hive.applied_hardforks' );
    PERFORM hive.restore_foreign_keys( 'hive.irreversible_data' );
    PERFORM hive.restore_foreign_keys( 'hive.accounts' );
    PERFORM hive.restore_foreign_keys( 'hive.account_operations' );

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
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'blocks_reversible' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'transactions_reversible' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'transactions_multisig_reversible' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'operations_reversible' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'applied_hardforks_reversible' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'accounts_reversible' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'account_operations_reversible' );



    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'blocks_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'transactions_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'transactions_multisig_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'operations_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'applied_hardforks_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'accounts_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'account_operations_reversible' );

    PERFORM hive.reanalyze_indexes_with_expressions();

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
    PERFORM hive.restore_indexes( 'hive.blocks_reversible' );
    PERFORM hive.restore_indexes( 'hive.transactions_reversible' );
    PERFORM hive.restore_indexes( 'hive.transactions_multisig_reversible' );
    PERFORM hive.restore_indexes( 'hive.operations_reversible' );
    PERFORM hive.restore_indexes( 'hive.accounts_reversible' );
    PERFORM hive.restore_indexes( 'hive.account_operations_reversible' );
    PERFORM hive.restore_indexes( 'hive.applied_hardforks_reversible' );



    PERFORM hive.restore_foreign_keys( 'hive.blocks_reversible' );
    PERFORM hive.restore_foreign_keys( 'hive.transactions_reversible' );
    PERFORM hive.restore_foreign_keys( 'hive.transactions_multisig_reversible' );
    PERFORM hive.restore_foreign_keys( 'hive.operations_reversible' );
    PERFORM hive.restore_foreign_keys( 'hive.accounts_reversible' );
    PERFORM hive.restore_foreign_keys( 'hive.account_operations_reversible' );
    PERFORM hive.restore_foreign_keys( 'hive.applied_hardforks_reversible' );

    PERFORM hive.reanalyze_indexes_with_expressions();
END;
$BODY$
;



CREATE OR REPLACE FUNCTION hive.connect( _git_sha TEXT, _block_num hive.blocks.num%TYPE )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.remove_inconsistent_irreversible_data();
    PERFORM hive.back_from_fork( _block_num );
    INSERT INTO hive.hived_connections( block_num, git_sha, time )
    VALUES( _block_num, _git_sha, now() );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.are_indexes_dropped()
    RETURNS BOOL
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __number_of_dropped_indexes INT;
BEGIN
    SELECT COUNT(*) FROM hive.indexes_constraints
    WHERE is_index
    INTO __number_of_dropped_indexes;
    IF ( __number_of_dropped_indexes = 0 ) THEN
        RETURN FALSE;
    ELSE
        RETURN TRUE;
    END IF;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.are_fk_dropped()
    RETURNS BOOL
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __number_of_dropped_fk INT;
BEGIN
    SELECT COUNT(*) FROM hive.indexes_constraints
    WHERE is_foreign_key
    INTO __number_of_dropped_fk;
    IF ( __number_of_dropped_fk = 0 ) THEN
        RETURN FALSE;
    ELSE
        RETURN TRUE;
    END IF;
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
    IF EXISTS ( SELECT 1 FROM hive.events_queue WHERE id = hive.unreachable_event_id() LIMIT 1 ) THEN
        SELECT MAX(eq.id) + 1 FROM hive.events_queue eq WHERE eq.id != hive.unreachable_event_id() INTO __events_id;
        PERFORM SETVAL( 'hive.events_queue_id_seq', __events_id, false );
        PERFORM hive.create_database_hash('hive');
        RETURN;
    END IF;

    INSERT INTO hive.irreversible_data VALUES(1,NULL, FALSE) ON CONFLICT DO NOTHING;
    INSERT INTO hive.events_queue VALUES( 0, 'NEW_IRREVERSIBLE', 0 ) ON CONFLICT DO NOTHING;
    INSERT INTO hive.events_queue VALUES( hive.unreachable_event_id(), 'NEW_BLOCK', 2147483647 ) ON CONFLICT DO NOTHING;
    SELECT MAX(eq.id) + 1 FROM hive.events_queue eq WHERE eq.id != hive.unreachable_event_id() INTO __events_id;
    PERFORM SETVAL( 'hive.events_queue_id_seq', __events_id, false );

    INSERT INTO hive.fork(block_num, time_of_fork) VALUES( 1, '2016-03-24 16:05:00'::timestamp ) ON CONFLICT DO NOTHING;

    PERFORM hive.create_database_hash('hive');
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
    INSERT INTO hive.write_ahead_log_state VALUES (1, _new_sequence_number)
    ON CONFLICT (id) DO UPDATE SET last_sequence_number_committed = _new_sequence_number WHERE hive.write_ahead_log_state.id = 1;
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
    SELECT last_sequence_number_committed FROM hive.write_ahead_log_state WHERE id = 1 INTO __last_sequence_number_committed;
    return __last_sequence_number_committed;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE hive.proc_perform_dead_app_contexts_auto_detach( IN _app_timeout INTERVAL DEFAULT '4 hours'::INTERVAL )
    LANGUAGE plpgsql
AS
$BODY$
DECLARE
  __contexts hive.context_name[];
  __ctx TEXT;
  __now TIMESTAMP WITHOUT TIME ZONE := NOW();
  __current_block_before_detach INT;
BEGIN
  SELECT ARRAY_AGG(c.name) INTO __contexts
  FROM hive.contexts c
  WHERE c.is_attached AND c.last_active_at < __now - _app_timeout;

  IF CARDINALITY(__contexts) != 0 THEN
    RAISE WARNING 'Attempting to automatically detach application contexts: %', __contexts;

    FOREACH __ctx IN ARRAY __contexts
    LOOP
      BEGIN
      RAISE WARNING 'Attempting to automatically detach application context: %', __ctx;
      SELECT hc.current_block_num INTO __current_block_before_detach
      FROM hive.contexts hc WHERE hc.name = __ctx;
      PERFORM hive.app_context_detach(__ctx);
      -- Detach functionality is specifically designed for use within the application's main loop.
      -- It automatically steps back by one block, which is previously incremented by 'app_next_block.'
      -- This design removes from applications obligation managing the 'current_block' explicitly.
      -- However, it's crucial to note that auto-detach is initiated outside the main application loop,
      -- and as such, it must refrain from modifying the 'current_block.', otherwise
      -- it can lead to scenarios where re-attached applications will process
      -- the same block twice after being auto-detached and subsequently restarted.

      UPDATE hive.contexts
      SET current_block_num = __current_block_before_detach
      WHERE name = __ctx;
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

