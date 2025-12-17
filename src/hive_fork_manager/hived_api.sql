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

    -- Insert transactions (original compact format with block_num)
    INSERT INTO hafd.transactions (block_num, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature)
    SELECT t.block_num, t.trx_in_block, t.trx_hash, t.ref_block_num, t.ref_block_prefix, t.expiration, t.signature
    FROM unnest(_transactions) t;

    -- Insert multisig signatures (original compact format with trx_hash)
    INSERT INTO hafd.transactions_multisig (trx_hash, signature)
    SELECT s.trx_hash, s.signature
    FROM unnest(_signatures) s;

    -- Insert operations (original compact format with encoded id)
    INSERT INTO hafd.operations (id, trx_in_block, op_pos, body_binary)
    SELECT o.id, o.trx_in_block, o.op_pos, o.body_binary
    FROM unnest(_operations) o;

    -- Insert accounts (original compact format with block_num)
    INSERT INTO hafd.accounts (id, name, block_num)
    SELECT a.id, a.name, a.block_num
    FROM unnest(_accounts) a
    ON CONFLICT (id) DO NOTHING;  -- Account may already exist

    -- Insert account_operations (original compact format with operation_id)
    INSERT INTO hafd.account_operations (account_id, transacting_account_id, account_op_seq_no, operation_id)
    SELECT ao.account_id, ao.transacting_account_id, ao.account_op_seq_no, ao.operation_id
    FROM unnest(_account_operations) ao;

    -- Insert applied_hardforks (original compact format with block_num)
    INSERT INTO hafd.applied_hardforks (hardfork_num, block_num, hardfork_vop_id)
    SELECT h.hardfork_num, h.block_num, h.hardfork_vop_id
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

CREATE OR REPLACE FUNCTION hive.remove_orphan_forks( _block_num INT )
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
    WHERE hafd.block_id_to_num(block_id) <= _block_num
      AND hafd.block_id_to_fork(block_id) != __canonical_fork_id;

    IF __orphan_block_nums IS NULL OR array_length(__orphan_block_nums, 1) = 0 THEN
        RETURN;
    END IF;

    -- Delete orphan blocks
    DELETE FROM hafd.blocks
    WHERE hafd.block_id_to_num(block_id) <= _block_num
      AND hafd.block_id_to_fork(block_id) != __canonical_fork_id;

    -- Clean up other tables by block_num (no FK CASCADE needed)
    DELETE FROM hafd.transactions WHERE block_num = ANY(__orphan_block_nums);
    DELETE FROM hafd.operations WHERE hafd.operation_id_to_block_num(id) = ANY(__orphan_block_nums);
    DELETE FROM hafd.account_operations WHERE hafd.operation_id_to_block_num(operation_id) = ANY(__orphan_block_nums);
    DELETE FROM hafd.applied_hardforks WHERE block_num = ANY(__orphan_block_nums);
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
