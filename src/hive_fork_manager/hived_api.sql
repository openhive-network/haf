-- =============================================================================
-- HIVED API Functions
-- =============================================================================
-- These functions are called by hived to push blocks and manage irreversibility.
-- blocks table uses block_id encoding for fork tracking.
-- Other tables use original compact format for performance during massive sync.
-- Fork cleanup is done explicitly (rare operation).
-- =============================================================================

-- =============================================================================
-- Input types for push_block (match hived's output format - original structure)
-- =============================================================================

DROP TYPE IF EXISTS hafd.blocks_type CASCADE;
CREATE TYPE hafd.blocks_type AS (
    num INTEGER,
    hash bytea,
    prev bytea,
    created_at timestamp without time zone,
    producer_account_id INTEGER,
    transaction_merkle_root bytea,
    extensions jsonb,
    witness_signature bytea,
    signing_key text,
    hbd_interest_rate INTEGER,
    total_vesting_fund_hive NUMERIC,
    total_vesting_shares NUMERIC,
    total_reward_fund_hive NUMERIC,
    virtual_supply NUMERIC,
    current_supply NUMERIC,
    current_hbd_supply NUMERIC,
    dhf_interval_ledger NUMERIC
);

DROP TYPE IF EXISTS hafd.transactions_type CASCADE;
CREATE TYPE hafd.transactions_type AS (
    block_num INTEGER,
    trx_in_block smallint,
    trx_hash bytea,
    ref_block_num integer,
    ref_block_prefix bigint,
    expiration timestamp without time zone,
    signature bytea
);

DROP TYPE IF EXISTS hafd.transactions_multisig_type CASCADE;
CREATE TYPE hafd.transactions_multisig_type AS (
    trx_hash bytea,
    signature bytea
);

DROP TYPE IF EXISTS hafd.operations_type CASCADE;
CREATE TYPE hafd.operations_type AS (
    id BIGINT,  -- Encoded (block_num | seq_in_block | op_type_id)
    trx_in_block smallint,
    op_pos integer,
    body_binary hafd.operation
);

DROP TYPE IF EXISTS hafd.accounts_type CASCADE;
CREATE TYPE hafd.accounts_type AS (
    id INTEGER,
    name VARCHAR(16),
    block_num INTEGER
);

DROP TYPE IF EXISTS hafd.account_operations_type CASCADE;
CREATE TYPE hafd.account_operations_type AS (
    account_id INTEGER,
    transacting_account_id INTEGER,
    account_op_seq_no INTEGER,
    operation_id BIGINT  -- Encoded operation_id
);

DROP TYPE IF EXISTS hafd.applied_hardforks_type CASCADE;
CREATE TYPE hafd.applied_hardforks_type AS (
    hardfork_num smallint,
    block_num INTEGER,
    hardfork_vop_id bigint
);

-- =============================================================================
-- API Functions
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.reanalyze_indexes_with_expressions()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- Analyze tables which indexes use expressions
    ANALYZE hafd.operations;
    ANALYZE hafd.account_operations;
    ANALYZE hafd.blocks;
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

-- =============================================================================
-- push_block - Insert new block data
-- =============================================================================
-- blocks uses block_id encoding for fork tracking.
-- Other tables use original compact format for maximum performance.

CREATE OR REPLACE FUNCTION hive.push_block(
      _block hafd.blocks_type
    , _transactions hafd.transactions_type[]
    , _signatures hafd.transactions_multisig_type[]
    , _operations hafd.operations_type[]
    , _accounts hafd.accounts_type[]
    , _account_operations hafd.account_operations_type[]
    , _applied_hardforks hafd.applied_hardforks_type[]
)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __fork_id hafd.fork.id%TYPE;
    __block_id hafd.block_id;
BEGIN
    -- Get current fork_id
    SELECT hf.id
    INTO __fork_id
    FROM hafd.fork hf ORDER BY hf.id DESC LIMIT 1;

    -- Generate block_id encoding (block_num, fork_id) for blocks table
    __block_id := hafd.make_block_id(_block.num, __fork_id);

    -- Insert event
    INSERT INTO hafd.events_queue( event, block_num )
        VALUES( 'NEW_BLOCK', _block.num );

    -- Insert into blocks table (uses block_id)
    INSERT INTO hafd.blocks (
        block_id, hash, prev, created_at, producer_account_id,
        transaction_merkle_root, extensions, witness_signature, signing_key,
        hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares,
        total_reward_fund_hive, virtual_supply, current_supply,
        current_hbd_supply, dhf_interval_ledger
    ) VALUES (
        __block_id, _block.hash, _block.prev, _block.created_at, _block.producer_account_id,
        _block.transaction_merkle_root, _block.extensions, _block.witness_signature, _block.signing_key,
        _block.hbd_interest_rate, _block.total_vesting_fund_hive, _block.total_vesting_shares,
        _block.total_reward_fund_hive, _block.virtual_supply, _block.current_supply,
        _block.current_hbd_supply, _block.dhf_interval_ledger
    );

    -- Insert transactions (original compact format with block_id)
    INSERT INTO hafd.transactions (block_id, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature)
    SELECT __block_id, t.trx_in_block, t.trx_hash, t.ref_block_num, t.ref_block_prefix, t.expiration, t.signature
    FROM unnest(_transactions) t;

    -- Insert multisig signatures (original compact format with trx_hash)
    INSERT INTO hafd.transactions_multisig (trx_hash, signature)
    SELECT s.trx_hash, s.signature
    FROM unnest(_signatures) s;

    -- Insert operations (original compact format with encoded id turned into columns)
    INSERT INTO hafd.operations (block_id, seq_in_block, op_type_id, trx_in_block, op_pos, body_binary)
    SELECT __block_id, (o.id >> 8) & 16777215, o.id & 255, o.trx_in_block, o.op_pos, o.body_binary
    FROM unnest(_operations) o;

    -- Insert accounts (original compact format with block_id)
    INSERT INTO hafd.accounts (id, name, block_id)
    SELECT a.id, a.name, __block_id
    FROM unnest(_accounts) a
    ON CONFLICT (id) DO NOTHING;  -- Account may already exist

    -- Insert account_operations (original compact format with block_id, seq_in_block)
    INSERT INTO hafd.account_operations (account_id, transacting_account_id, account_op_seq_no, block_id, seq_in_block)
    SELECT ao.account_id, ao.transacting_account_id, ao.account_op_seq_no, __block_id, (ao.operation_id >> 8) & 16777215
    FROM unnest(_account_operations) ao;

    -- Insert applied_hardforks (original compact format with block_id)
    INSERT INTO hafd.applied_hardforks (hardfork_num, block_id, hardfork_vop_id)
    SELECT h.hardfork_num, __block_id, h.hardfork_vop_id
    FROM unnest(_applied_hardforks) h
    ON CONFLICT (hardfork_num) DO NOTHING;  -- Hardfork may already be recorded
END;
$BODY$
;

-- =============================================================================
-- set_irreversible - Mark blocks as irreversible
-- =============================================================================
-- With hybrid structure, we delete orphan fork blocks.
-- Other tables don't have FK CASCADE, so fork cleanup handles them separately.

CREATE OR REPLACE FUNCTION hive.set_irreversible( _block_num INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __current_irreversible INT;
BEGIN
    SELECT COALESCE(hafd.block_id_to_num(consistent_block), 0) INTO __current_irreversible FROM hafd.hive_state;

    IF ( _block_num <= __current_irreversible ) THEN
        RETURN;
    END IF;

    -- Try to cleanup orphan forks (non-blocking)
    BEGIN
        LOCK TABLE hafd.contexts_attachment IN EXCLUSIVE MODE NOWAIT;
        PERFORM hive.remove_unecessary_events( _block_num );
        PERFORM hive.remove_orphan_forks( _block_num );
    EXCEPTION WHEN SQLSTATE '55P03' THEN
        -- 55P03 lock_not_available - contexts are locked by apps
    END;

    -- Signal applications
    INSERT INTO hafd.events_queue( event, block_num )
    VALUES( 'NEW_IRREVERSIBLE', _block_num );

    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(_block_num, (SELECT MAX(id) FROM hafd.fork));
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
    BEGIN
        LOCK TABLE hafd.contexts_attachment IN EXCLUSIVE MODE NOWAIT;
        PERFORM hive.remove_unecessary_events( _block_num );
        PERFORM hive.remove_orphan_forks( _block_num );
    EXCEPTION WHEN SQLSTATE '55P03' THEN
        -- 55P03 lock_not_available
    END;

    INSERT INTO hafd.events_queue( event, block_num )
    VALUES ( 'MASSIVE_SYNC'::hafd.event_type, _block_num );

    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(_block_num, (SELECT MAX(id) FROM hafd.fork));
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

-- =============================================================================
-- Index management functions
-- =============================================================================

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

-- =============================================================================
-- Reversible index functions - NO-OP with hybrid structure
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.disable_indexes_of_reversible()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- NO-OP: No separate reversible tables
    NULL;
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
    -- NO-OP: No separate reversible tables
    NULL;
END;
$BODY$
;

-- =============================================================================
-- Connection and initialization
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.connect( _git_sha TEXT, _block_num INT, _first_block INT, _pruning integer )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __max_block INT;
    __last_pruning integer;
BEGIN
    SELECT hafd.block_id_to_num(block_id) INTO __max_block
    FROM hafd.blocks
    ORDER BY block_id DESC
    LIMIT 1;

    SELECT pruning INTO __last_pruning FROM hafd.hive_state;

    IF ( __max_block IS NOT NULL AND __max_block > _block_num ) THEN
        RAISE EXCEPTION 'Hived data start block (%) is lower than HAF database head block (%). This indicates a hived/HAF mismatch and could result in corrupted data.', _block_num, __max_block;
    END IF;

    IF __last_pruning IS NOT NULL AND __last_pruning != 0 AND _pruning != __last_pruning THEN
        RAISE EXCEPTION 'Not possible to change pruning from % to %', __last_pruning, _pruning;
    END IF;

    IF _pruning != 0 THEN
        UPDATE hafd.hive_state SET pruning = _pruning;
    END IF;
END;
$BODY$
;

-- =============================================================================
-- remove_orphan_forks - Clean up orphan fork data
-- =============================================================================
-- With hybrid structure, blocks uses block_id. Other tables use block_num.
-- We delete orphan blocks, then clean up other tables by block_num.

CREATE OR REPLACE FUNCTION hive.remove_orphan_forks( _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __canonical_fork_id BIGINT;
    __orphan_block_nums INT[];
BEGIN
    -- Get canonical fork_id
    SELECT MAX(id) INTO __canonical_fork_id FROM hafd.fork;

    -- Find orphan block_nums (blocks on non-canonical forks)
    SELECT array_agg(DISTINCT hafd.block_id_to_num(block_id))
    INTO __orphan_block_nums
    FROM hafd.blocks
    WHERE hafd.block_id_to_num(block_id) <= _new_irreversible_block
      AND hafd.block_id_to_fork(block_id) != __canonical_fork_id;

    IF __orphan_block_nums IS NULL OR array_length(__orphan_block_nums, 1) = 0 THEN
        RETURN;
    END IF;

    -- Delete orphan blocks
    DELETE FROM hafd.blocks
    WHERE hafd.block_id_to_num(block_id) <= _new_irreversible_block
      AND hafd.block_id_to_fork(block_id) != __canonical_fork_id;

    -- Clean up other tables by block_num (no FK CASCADE needed)
    DELETE FROM hafd.transactions WHERE hafd.block_id_to_num(block_id) = ANY(__orphan_block_nums);
    DELETE FROM hafd.operations WHERE hafd.block_id_to_num(block_id) = ANY(__orphan_block_nums);
    DELETE FROM hafd.account_operations WHERE hafd.block_id_to_num(block_id) = ANY(__orphan_block_nums);
    DELETE FROM hafd.applied_hardforks WHERE hafd.block_id_to_num(block_id) = ANY(__orphan_block_nums);
    -- Note: accounts and transactions_multisig don't need cleanup (accounts persist, multisig cascades from transactions)
END;
$BODY$
;

-- =============================================================================
-- Utility functions
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.is_pruning_enabled()
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __pruning integer;
BEGIN
    SELECT pruning INTO __pruning FROM hafd.hive_state;
    RETURN __pruning IS NOT NULL AND __pruning != 0;
END;
$BODY$
;

-- =============================================================================
-- Index status check functions
-- =============================================================================

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

-- =============================================================================
-- Extension initialization
-- =============================================================================

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
        RETURN;
    END IF;

    INSERT INTO hafd.hive_state VALUES(1,NULL, FALSE) ON CONFLICT DO NOTHING;
    INSERT INTO hafd.events_queue VALUES( 0, 'NEW_IRREVERSIBLE', 0 ) ON CONFLICT DO NOTHING;
    INSERT INTO hafd.events_queue VALUES( hive.unreachable_event_id(), 'NEW_BLOCK', 2147483647 ) ON CONFLICT DO NOTHING;
    SELECT MAX(eq.id) + 1 FROM hafd.events_queue eq WHERE eq.id != hive.unreachable_event_id() INTO __events_id;
    PERFORM SETVAL( 'hafd.events_queue_id_seq', __events_id, false );

    INSERT INTO hafd.fork(block_num, time_of_fork) VALUES( 1, '2016-03-24 16:05:00'::timestamp ) ON CONFLICT DO NOTHING;

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

-- =============================================================================
-- WAL sequence number functions
-- =============================================================================

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

-- =============================================================================
-- Dead context auto-detach procedure
-- =============================================================================

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

-- =============================================================================
-- Sync state functions
-- =============================================================================

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

-- =============================================================================
-- Vacuum helper functions
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.get_vacuum_full_commands(schema_name TEXT DEFAULT 'hafd')
RETURNS SETOF TEXT
LANGUAGE sql
AS $$
    SELECT format('VACUUM FULL %I.%I;', schemaname, tablename) as vacuum_cmd
    FROM pg_tables
    WHERE schemaname = schema_name;
$$;
