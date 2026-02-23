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
    id BIGINT,  -- Encoded (block_num | pos_in_block)
    trx_in_block smallint,
    op_type_id smallint,
    op_pos integer,
    body_binary hafd.operation,
    custom_json_type_id INTEGER
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
    operation_id BIGINT,  -- Encoded (block_num | pos_in_block)
    op_type_id smallint
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
    IF hive.is_lite_mode() THEN
        DELETE FROM hafd.account_operations
            USING hafd.operations
            WHERE hafd.account_operations.operation_id = hafd.operations.id
              AND hafd.operation_id_to_block_num(hafd.operations.id) > _block_num_before_fork;
        DELETE FROM hafd.applied_hardforks WHERE block_num > _block_num_before_fork;
        DELETE FROM hafd.operations WHERE hafd.operation_id_to_block_num(id) > _block_num_before_fork;
        DELETE FROM hafd.transactions_multisig
            USING hafd.transactions
            WHERE hafd.transactions_multisig.trx_hash = hafd.transactions.trx_hash
              AND hafd.transactions.block_num > _block_num_before_fork;
        DELETE FROM hafd.transactions WHERE block_num > _block_num_before_fork;
        UPDATE hafd.accounts SET block_num = NULL WHERE block_num > _block_num_before_fork;
        DELETE FROM hafd.blocks WHERE num > _block_num_before_fork;
        RETURN;
    END IF;

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
    INSERT INTO hafd.transactions_multisig (trx_hash, signature, block_id)
    SELECT s.trx_hash, s.signature, __block_id
    FROM unnest(_signatures) s;

    -- Insert operations (original compact format with encoded id)
    -- o.id encodes: (block_num << 32) | pos_in_block
    -- op_type_id is stored as a separate column
    INSERT INTO hafd.operations (block_id, trx_in_block, op_type_id, op_pos, body_binary, id, custom_json_type_id)
    SELECT __block_id, o.trx_in_block, o.op_type_id, o.op_pos, o.body_binary, o.id, o.custom_json_type_id
    FROM unnest(_operations) o;

    -- Insert accounts (original compact format with block_id)
    -- Same account can exist on different forks (different block_id values)
    INSERT INTO hafd.accounts (id, name, block_id)
    SELECT a.id, a.name, __block_id
    FROM unnest(_accounts) a
    ON CONFLICT ON CONSTRAINT uq_hive_accounts DO NOTHING;

    -- Insert account_operations with operation_id stored directly (avoids JOIN in views)
    INSERT INTO hafd.account_operations (account_id, transacting_account_id, account_op_seq_no, block_id, operation_id, op_type_id)
    SELECT ao.account_id, ao.transacting_account_id, ao.account_op_seq_no, __block_id, ao.operation_id, ao.op_type_id
    FROM unnest(_account_operations) ao;

    -- Insert applied_hardforks (original compact format with block_id)
    INSERT INTO hafd.applied_hardforks (hardfork_num, block_id, hardfork_vop_id)
    SELECT h.hardfork_num, __block_id, h.hardfork_vop_id
    FROM unnest(_applied_hardforks) h
    ON CONFLICT (hardfork_num, block_id) DO NOTHING;  -- Hardfork may already be recorded in this fork

    -- Track conflict if this block_num already has another version (different fork)
    -- This enables views to skip canonical selection for non-conflicted blocks (fast path)
    INSERT INTO hafd.block_conflicts (block_num)
    SELECT _block.num
    WHERE EXISTS (
        SELECT 1 FROM hafd.blocks hb
        WHERE hafd.block_id_to_num(hb.block_id) = _block.num
          AND hb.block_id != __block_id
    )
    ON CONFLICT (block_num) DO NOTHING;
END;
$BODY$
;


-- =============================================================================
-- push_block_lite - Insert new block data in lite mode (no fork handling)
-- =============================================================================
-- In lite mode, blocks are treated as immediately irreversible.
-- No fork tracking, no block_conflicts, no reversible event.

CREATE OR REPLACE FUNCTION hive.push_block_lite(
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
    SELECT hf.id INTO __fork_id FROM hafd.fork hf ORDER BY hf.id DESC LIMIT 1;
    __block_id := hafd.make_block_id(_block.num, __fork_id);

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

    INSERT INTO hafd.transactions (block_id, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature)
    SELECT __block_id, t.trx_in_block, t.trx_hash, t.ref_block_num, t.ref_block_prefix, t.expiration, t.signature
    FROM unnest(_transactions) t;

    INSERT INTO hafd.transactions_multisig (trx_hash, signature, block_id)
    SELECT s.trx_hash, s.signature, __block_id
    FROM unnest(_signatures) s;

    INSERT INTO hafd.operations (block_id, trx_in_block, op_pos, body_binary, id)
    SELECT __block_id, o.trx_in_block, o.op_pos, o.body_binary, o.id
    FROM unnest(_operations) o;

    INSERT INTO hafd.accounts (id, name, block_id)
    SELECT a.id, a.name, __block_id
    FROM unnest(_accounts) a
    ON CONFLICT ON CONSTRAINT uq_hive_accounts DO NOTHING;

    INSERT INTO hafd.account_operations (account_id, transacting_account_id, account_op_seq_no, block_id, operation_id)
    SELECT ao.account_id, ao.transacting_account_id, ao.account_op_seq_no, __block_id, ao.operation_id
    FROM unnest(_account_operations) ao;

    INSERT INTO hafd.applied_hardforks (hardfork_num, block_id, hardfork_vop_id)
    SELECT h.hardfork_num, __block_id, h.hardfork_vop_id
    FROM unnest(_applied_hardforks) h
    ON CONFLICT (hardfork_num, block_id) DO NOTHING;

    INSERT INTO hafd.events_queue( event, block_num )
    VALUES( 'NEW_IRREVERSIBLE', _block.num );

    UPDATE hafd.hive_state SET consistent_block = __block_id;

    BEGIN
        LOCK TABLE hafd.contexts_attachment IN EXCLUSIVE MODE NOWAIT;
        PERFORM hive.remove_unecessary_events( _block.num );
    EXCEPTION WHEN SQLSTATE '55P03' THEN
        -- lock_not_available
    END;
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
    IF hive.is_lite_mode() THEN
        -- In lite mode, data is already in irreversible tables (inserted by push_block_lite).
        -- Just emit the event and update consistent_block.
        INSERT INTO hafd.events_queue( event, block_num )
        VALUES( 'NEW_IRREVERSIBLE', _block_num );
        UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(_block_num, (SELECT MAX(id) FROM hafd.fork));

        BEGIN
            LOCK TABLE hafd.contexts_attachment IN EXCLUSIVE MODE NOWAIT;
            PERFORM hive.remove_unecessary_events( _block_num );
        EXCEPTION WHEN SQLSTATE '55P03' THEN
            -- lock_not_available
        END;
        RETURN;
    END IF;

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
    -- NOTE: reanalyze_indexes_with_expressions() removed from here.
    -- ANALYZE is only needed after indexes are RESTORED (in enable_indexes_of_irreversible),
    -- not after they are dropped. Statistics for dropped indexes are irrelevant.
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


CREATE OR REPLACE FUNCTION hive.connect( _git_sha TEXT, _block_num INT, _first_block INT, _pruning integer, _lite_mode boolean DEFAULT FALSE )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __max_block INT;
    __last_pruning integer;
    __existing_lite_mode boolean;
BEGIN
    -- Validate lite_mode consistency: cannot switch modes on an existing DB with data
    SELECT lite_mode INTO __existing_lite_mode FROM hafd.hive_state;

    -- assumptions:
    -- sql-serializer WAL was replayed after (re)start
    -- at the moment of call hived finished restarting and did removing reversible data from state if it was desired
    PERFORM hive.remove_inconsistent_irreversible_data();

    SELECT MAX(num) INTO __max_block FROM hive.blocks_view;

    IF COALESCE(__max_block, 0) > 0 THEN
        ASSERT __existing_lite_mode = _lite_mode,
            format('Cannot switch lite mode: database has %s blocks and lite_mode is %s, but requested %s',
                   __max_block, __existing_lite_mode, _lite_mode);
    END IF;

    UPDATE hafd.hive_state SET lite_mode = _lite_mode;

    SELECT pruning INTO __last_pruning FROM hafd.hive_state;

    IF _lite_mode THEN
        -- In lite mode, clean up blocks beyond _block_num directly
        IF COALESCE(__max_block, 0) > _block_num OR _block_num = 0 THEN
            DELETE FROM hafd.account_operations
                USING hafd.operations
                WHERE hafd.account_operations.operation_id = hafd.operations.id
                  AND hafd.operation_id_to_block_num(hafd.operations.id) > _block_num;
            DELETE FROM hafd.applied_hardforks WHERE hafd.block_id_to_num(block_id) > _block_num;
            DELETE FROM hafd.operations WHERE hafd.operation_id_to_block_num(id) > _block_num;
            DELETE FROM hafd.transactions_multisig
                USING hafd.transactions
                WHERE hafd.transactions_multisig.trx_hash = hafd.transactions.trx_hash
                  AND hafd.block_id_to_num(hafd.transactions.block_id) > _block_num;
            DELETE FROM hafd.transactions WHERE hafd.block_id_to_num(block_id) > _block_num;
            DELETE FROM hafd.accounts WHERE hafd.block_id_to_num(block_id) > _block_num;
            DELETE FROM hafd.blocks WHERE hafd.block_id_to_num(block_id) > _block_num;
        END IF;
    ELSE
        -- After WAL replay, HAF should have at least as many blocks as hived's state reports.
        -- If HAF has fewer blocks than hived, something is wrong (data loss).
        -- Exception: when max_block < _first_block (pruned scenario) this is expected.
        ASSERT COALESCE(__max_block, 0) >= _block_num OR COALESCE(__max_block, 0) < _first_block,
            format('Hived state cannot have more blocks on top micro fork than HAF. max_block=%s, _block_num=%s', __max_block, _block_num);

        -- If max_block > _block_num, we need to handle fork situation
        -- _block_num = 0 ensures at least 1 fork exists
        IF __max_block > _block_num OR _block_num = 0 THEN
            PERFORM hive.back_from_fork( _block_num );
        END IF;
    END IF;

    -- Record the connection
    INSERT INTO hafd.hived_connections( block_num, git_sha, time )
    VALUES( _block_num, _git_sha, now() );

    -- Pruning validation and setup
    ASSERT ( hive.is_pruning_enabled() = FALSE OR ( hive.is_pruning_enabled() = TRUE AND _pruning > 0 ) ),
        'Cannot initialize as non-pruned: existing database is pruned. Drop/recreate the database or run in pruned mode.';

    UPDATE hafd.hive_state SET pruning = _pruning;

    IF hive.is_pruning_enabled() = TRUE THEN
        -- Drop FK for faster operations on pruned data
        ALTER TABLE hafd.account_operations DROP CONSTRAINT IF EXISTS hive_account_operations_fk_2;
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
    __blocks_to_delete hafd.block_id[];
    __current_state hafd.sync_state;
BEGIN
    -- Early exit: Forks only happen during LIVE mode when receiving blocks from
    -- the network in real-time. During REINDEX (block log replay) and P2P (catching
    -- up from network), all blocks are on a single fork, so there can't be any
    -- orphan forks. This avoids expensive full table scans.
    SELECT state INTO __current_state FROM hafd.hive_state;
    IF __current_state != 'LIVE' THEN
        RETURN;
    END IF;

    -- Fast path: if no block conflicts recorded, there are no orphan forks.
    -- block_conflicts is populated by push_block() when a block_num arrives
    -- on a different fork. If empty, skip the expensive full-table scan.
    IF NOT EXISTS (SELECT 1 FROM hafd.block_conflicts LIMIT 1) THEN
        RETURN;
    END IF;

    -- Identify blocks to delete:
    -- Only look at block_nums listed in block_conflicts (those with multiple versions).
    -- For each conflicted block_num <= _new_irreversible_block:
    -- Keep block with HIGHEST fork_id. Delete others (orphans).

    WITH conflicted_blocks AS (
        SELECT bc.block_num
        FROM hafd.block_conflicts bc
        WHERE bc.block_num <= _new_irreversible_block
    ),
    orphans AS (
        SELECT hb.block_id
        FROM hafd.blocks hb
        JOIN conflicted_blocks cb ON hafd.block_id_to_num(hb.block_id) = cb.block_num
        WHERE EXISTS (
              SELECT 1 FROM hafd.blocks hb2
              WHERE hafd.block_id_to_num(hb2.block_id) = cb.block_num
                AND hafd.block_id_to_fork(hb2.block_id) > hafd.block_id_to_fork(hb.block_id)
          )
    )
    SELECT array_agg(block_id) INTO __blocks_to_delete FROM orphans;

    IF __blocks_to_delete IS NULL OR cardinality(__blocks_to_delete) = 0 THEN
        RETURN;
    END IF;

    DELETE FROM hafd.operations WHERE block_id = ANY(__blocks_to_delete);
    DELETE FROM hafd.account_operations WHERE block_id = ANY(__blocks_to_delete);
    DELETE FROM hafd.transactions_multisig WHERE block_id = ANY(__blocks_to_delete);
    DELETE FROM hafd.transactions WHERE block_id = ANY(__blocks_to_delete);
    DELETE FROM hafd.accounts WHERE block_id = ANY(__blocks_to_delete);
    DELETE FROM hafd.applied_hardforks WHERE block_id = ANY(__blocks_to_delete);
    DELETE FROM hafd.blocks WHERE block_id = ANY(__blocks_to_delete);

    -- Clear conflicts for block_nums that were in deleted blocks
    -- After deleting orphan blocks, these block_nums have only one version remaining
    DELETE FROM hafd.block_conflicts
    WHERE block_num IN (
        SELECT hafd.block_id_to_num(block_id)
        FROM unnest(__blocks_to_delete) AS block_id
    );
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

    INSERT INTO hafd.hive_state VALUES(1, NULL, FALSE, 'START', 0, FALSE) ON CONFLICT DO NOTHING;
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

DROP FUNCTION IF EXISTS hive.get_vacuum_full_commands(TEXT);

CREATE OR REPLACE FUNCTION hive.get_vacuum_full_prune_commands(schema_name TEXT DEFAULT 'hafd')
RETURNS SETOF TEXT
LANGUAGE sql
AS $$
    SELECT format('VACUUM FULL %I.%I;', schemaname, tablename) as vacuum_cmd
    FROM pg_tables
    WHERE schemaname = schema_name;
$$;

CREATE OR REPLACE FUNCTION hive.get_vacuum_full_periodic_commands()
RETURNS SETOF TEXT
LANGUAGE sql
AS $$
    SELECT 'VACUUM FULL hafd.contexts;'::text
    UNION ALL
    SELECT 'VACUUM FULL hafd.hive_state;'::text
$$;
