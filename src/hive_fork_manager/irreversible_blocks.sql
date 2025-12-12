CREATE DOMAIN hafd.vest_amount AS NUMERIC NOT NULL;
CREATE DOMAIN hafd.hive_amount AS NUMERIC NOT NULL;
CREATE DOMAIN hafd.hbd_amount AS NUMERIC NOT NULL;
--- Interest rate (in BPS - basis points)
CREATE DOMAIN hafd.interest_rate AS INT4 NOT NULL;

-- =============================================================================
-- hafd.blocks - Unified table for both irreversible and reversible blocks
-- =============================================================================
-- block_id encodes (block_num, fork_id) in 64 bits:
--   Upper 32 bits = block_num
--   Lower 32 bits = fork_id
-- Same block_num can exist on multiple forks; only one is canonical.
-- On irreversibility: DELETE orphan forks (CASCADE handles children)

CREATE TABLE IF NOT EXISTS hafd.blocks (
    block_id hafd.block_id NOT NULL,
    hash bytea NOT NULL,
    prev bytea NOT NULL,
    created_at timestamp without time zone NOT NULL,
    producer_account_id INTEGER NOT NULL,
    transaction_merkle_root bytea NOT NULL,
    extensions jsonb DEFAULT NULL,
    witness_signature bytea NOT NULL,
    signing_key text NOT NULL,

    --- Data specific to parts of blockchain DGPO

    hbd_interest_rate hafd.interest_rate,

    total_vesting_fund_hive hafd.hive_amount,
    total_vesting_shares hafd.vest_amount,

    total_reward_fund_hive hafd.hive_amount,

    virtual_supply hafd.hive_amount,
    current_supply hafd.hive_amount,

    current_hbd_supply hafd.hbd_amount,
    dhf_interval_ledger hafd.hbd_amount,

    CONSTRAINT pk_hive_blocks PRIMARY KEY( block_id )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.blocks', '');

-- Functional index for block_num queries + canonical selection (ORDER BY block_id DESC)
CREATE INDEX IF NOT EXISTS hive_blocks_block_num_idx ON hafd.blocks (
    hafd.block_id_to_num(block_id),
    block_id DESC
);

CREATE INDEX IF NOT EXISTS hive_blocks_producer_account_id_idx ON hafd.blocks (producer_account_id);
CREATE INDEX IF NOT EXISTS hive_blocks_created_at_idx ON hafd.blocks USING btree ( created_at );

CREATE STATISTICS IF NOT EXISTS blocks_block_num_stats ON (hafd.block_id_to_num(block_id)) FROM hafd.blocks;

-- =============================================================================
-- hafd.hive_state - System state tracking
-- =============================================================================

CREATE TYPE hafd.sync_state AS ENUM (
    'START', 'WAIT', 'REINDEX_WAIT', 'REINDEX', 'P2P', 'LIVE'
);

CREATE TABLE IF NOT EXISTS hafd.hive_state (
    id integer,
    consistent_block integer,
    is_dirty bool NOT NULL,
    state hafd.sync_state NOT NULL DEFAULT 'START',
    pruning integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_irreversible_data PRIMARY KEY ( id )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.hive_state', '');
-- Note: FK to blocks removed - consistent_block is just a block_num value, not a block_id

-- =============================================================================
-- hafd.transactions - Unified transactions table
-- =============================================================================

CREATE TABLE IF NOT EXISTS hafd.transactions (
    block_id hafd.block_id NOT NULL,
    trx_in_block smallint NOT NULL,
    trx_hash bytea NOT NULL,
    ref_block_num integer NOT NULL,
    ref_block_prefix bigint NOT NULL,
    expiration timestamp without time zone NOT NULL,
    signature bytea DEFAULT NULL,
    CONSTRAINT pk_hive_transactions PRIMARY KEY ( block_id, trx_in_block ),
    CONSTRAINT fk_1_hive_transactions FOREIGN KEY (block_id) REFERENCES hafd.blocks (block_id) ON DELETE CASCADE NOT VALID
);
SELECT pg_catalog.pg_extension_config_dump('hafd.transactions', '');

-- Index for trx_hash lookups (common query pattern)
CREATE UNIQUE INDEX IF NOT EXISTS hive_transactions_trx_hash_idx ON hafd.transactions (trx_hash, block_id);

-- Functional index for block_num range queries
CREATE INDEX IF NOT EXISTS hive_transactions_block_num_idx ON hafd.transactions (
    hafd.block_id_to_num(block_id),
    block_id DESC
);

CREATE STATISTICS IF NOT EXISTS transactions_ref_block_dependency_stats (dependencies) ON ref_block_num, ref_block_prefix FROM hafd.transactions;
CREATE STATISTICS IF NOT EXISTS transactions_block_num_stats ON (hafd.block_id_to_num(block_id)) FROM hafd.transactions;

-- =============================================================================
-- hafd.transactions_multisig - Multi-signature transactions
-- =============================================================================

CREATE TABLE IF NOT EXISTS hafd.transactions_multisig (
    block_id hafd.block_id NOT NULL,
    trx_in_block smallint NOT NULL,
    signature bytea NOT NULL,
    CONSTRAINT pk_hive_transactions_multisig PRIMARY KEY ( block_id, trx_in_block, signature ),
    CONSTRAINT fk_1_hive_transactions_multisig FOREIGN KEY (block_id, trx_in_block) REFERENCES hafd.transactions (block_id, trx_in_block) ON DELETE CASCADE NOT VALID
);
SELECT pg_catalog.pg_extension_config_dump('hafd.transactions_multisig', '');

-- =============================================================================
-- hafd.operation_types - Operation type definitions (unchanged)
-- =============================================================================

CREATE TABLE IF NOT EXISTS hafd.operation_types (
    id smallint NOT NULL,
    name text NOT NULL,
    is_virtual boolean NOT NULL,
    CONSTRAINT pk_hive_operation_types PRIMARY KEY (id),
    CONSTRAINT uq_hive_operation_types UNIQUE (name)
);
SELECT pg_catalog.pg_extension_config_dump('hafd.operation_types', '');
CREATE STATISTICS IF NOT EXISTS operation_types_id_name_dependency_stats (dependencies) ON id, name FROM hafd.operation_types;

-- =============================================================================
-- hafd.operations - Unified operations table
-- =============================================================================
-- Changed from encoded id (block_num|seq|type) to composite PK (block_id, seq_in_block)
-- op_type_id is now a separate column for efficient filtering

CREATE TABLE IF NOT EXISTS hafd.operations (
    block_id hafd.block_id NOT NULL,
    seq_in_block integer NOT NULL,           -- sequence within block (was 24 bits in old id)
    op_type_id smallint NOT NULL,            -- operation type (was 8 bits in old id)
    trx_in_block smallint NOT NULL,
    op_pos integer NOT NULL,
    body_binary hafd.operation DEFAULT NULL,
    CONSTRAINT pk_hive_operations PRIMARY KEY ( block_id, seq_in_block ),
    CONSTRAINT fk_1_hive_operations FOREIGN KEY (block_id) REFERENCES hafd.blocks (block_id) ON DELETE CASCADE NOT VALID
);
SELECT pg_catalog.pg_extension_config_dump('hafd.operations', '');

-- Index for block_num range queries (most common pattern)
CREATE INDEX IF NOT EXISTS hive_operations_block_num_idx ON hafd.operations (
    hafd.block_id_to_num(block_id),
    block_id DESC,
    seq_in_block
);

-- Index for operation type filtering with block_num
CREATE INDEX IF NOT EXISTS hive_operations_type_block_num_idx ON hafd.operations (
    op_type_id,
    hafd.block_id_to_num(block_id)
);

-- Index for trx_in_block queries
CREATE INDEX IF NOT EXISTS hive_operations_block_num_trx_in_block_idx ON hafd.operations (
    hafd.block_id_to_num(block_id),
    trx_in_block,
    op_type_id
);

CREATE STATISTICS IF NOT EXISTS operations_block_num_stats ON (hafd.block_id_to_num(block_id)) FROM hafd.operations;

-- =============================================================================
-- hafd.applied_hardforks - Hardfork tracking
-- =============================================================================

CREATE TABLE IF NOT EXISTS hafd.applied_hardforks (
    block_id hafd.block_id NOT NULL,
    hardfork_num smallint NOT NULL,
    hardfork_vop_id bigint NOT NULL,  -- Legacy operation_id for compatibility
    CONSTRAINT pk_hive_applied_hardforks PRIMARY KEY (block_id, hardfork_num),
    CONSTRAINT fk_1_hive_applied_hardforks FOREIGN KEY (block_id) REFERENCES hafd.blocks(block_id) ON DELETE CASCADE NOT VALID
);
SELECT pg_catalog.pg_extension_config_dump('hafd.applied_hardforks', '');

CREATE INDEX IF NOT EXISTS hive_applied_hardforks_block_num_idx ON hafd.applied_hardforks (
    hafd.block_id_to_num(block_id)
);

CREATE STATISTICS IF NOT EXISTS applied_hardforks_block_num_stats ON (hafd.block_id_to_num(block_id)) FROM hafd.applied_hardforks;

-- =============================================================================
-- hafd.accounts - Account registry
-- =============================================================================
-- PK changed to (id, block_id) to support same account appearing on different forks

CREATE TABLE IF NOT EXISTS hafd.accounts (
    id INTEGER NOT NULL,
    name VARCHAR(16) NOT NULL,
    block_id hafd.block_id NOT NULL,
    CONSTRAINT pk_hive_accounts PRIMARY KEY( id, block_id ),
    CONSTRAINT fk_1_hive_accounts FOREIGN KEY (block_id) REFERENCES hafd.blocks (block_id) ON DELETE CASCADE NOT VALID
);
SELECT pg_catalog.pg_extension_config_dump('hafd.accounts', '');

-- Index for name lookups (canonical selection via block_id DESC)
CREATE INDEX IF NOT EXISTS hive_accounts_name_idx ON hafd.accounts (name, block_id DESC);

-- Index for block_id FK lookups (needed for CASCADE DELETE efficiency)
CREATE INDEX IF NOT EXISTS hive_accounts_block_id_idx ON hafd.accounts (block_id);

CREATE STATISTICS IF NOT EXISTS accounts_block_num_stats ON (hafd.block_id_to_num(block_id)) FROM hafd.accounts;

-- =============================================================================
-- hafd.account_operations - Account operation history
-- =============================================================================

CREATE TABLE IF NOT EXISTS hafd.account_operations (
    block_id hafd.block_id NOT NULL,
    seq_in_block integer NOT NULL,
    account_id INTEGER NOT NULL,
    transacting_account_id INTEGER NOT NULL,
    account_op_seq_no INTEGER NOT NULL,
    CONSTRAINT pk_hive_account_operations PRIMARY KEY ( block_id, seq_in_block, account_id ),
    CONSTRAINT fk_1_hive_account_operations FOREIGN KEY (block_id, seq_in_block) REFERENCES hafd.operations (block_id, seq_in_block) ON DELETE CASCADE NOT VALID
);
SELECT pg_catalog.pg_extension_config_dump('hafd.account_operations', '');

-- Index for account history queries (most important for get_account_history)
CREATE INDEX IF NOT EXISTS hive_account_operations_account_seq_idx ON hafd.account_operations (
    account_id,
    account_op_seq_no DESC
);

-- Index for operation type filtering by account
CREATE INDEX IF NOT EXISTS hive_account_operations_account_type_idx ON hafd.account_operations (
    account_id,
    block_id,
    seq_in_block
);

-- Index for block_num range queries
CREATE INDEX IF NOT EXISTS hive_account_operations_block_num_idx ON hafd.account_operations (
    hafd.block_id_to_num(block_id),
    block_id DESC
);

CREATE STATISTICS IF NOT EXISTS account_operations_block_num_stats ON (hafd.block_id_to_num(block_id)) FROM hafd.account_operations;

-- Clustering for get_account_history performance
CLUSTER hafd.account_operations USING hive_account_operations_account_seq_idx;

-- =============================================================================
-- hafd.write_ahead_log_state - WAL tracking (unchanged)
-- =============================================================================

CREATE TABLE hafd.write_ahead_log_state (id SMALLINT NOT NULL UNIQUE CHECK (id = 1), last_sequence_number_committed INTEGER);
COMMENT ON TABLE hafd.write_ahead_log_state IS 'Tracks the sequence numbers in hived''s write-ahead log';
COMMENT ON COLUMN hafd.write_ahead_log_state.id IS 'an id column.  this table will never have more than one row, and its id will be 1.  an empty table is semantically equivalent to a table where the last_sequence_number_committed is NULL';
COMMENT ON COLUMN hafd.write_ahead_log_state.last_sequence_number_committed IS 'The sequence number of the last commited transaction, or NULL if we''re operating in a mode that doesn''t track sequence numbers.  Will always be non-negative';

SELECT pg_catalog.pg_extension_config_dump('hafd.write_ahead_log_state', '');

-- =============================================================================
-- Note on blocks -> accounts relationship
-- =============================================================================
-- In the original design, producer_account_id referenced accounts(id) with a
-- deferred FK constraint. With the new multi-fork design where accounts can have
-- multiple rows per id (one per fork), maintaining this FK is complex and would
-- require matching fork_ids between blocks and accounts.
--
-- The constraint is removed because:
-- 1. It was already DEFERRABLE INITIALLY DEFERRED (for bootstrap reasons)
-- 2. With multi-fork data, referential integrity across forks is complex
-- 3. hived ensures producer accounts exist before writing blocks
-- 4. Views already handle canonical row selection via window functions

-- =============================================================================
-- Legacy compatibility functions for operation_id
-- =============================================================================
-- These functions compute legacy operation_id from new columns for API compatibility

CREATE OR REPLACE FUNCTION hafd.operation_id(_block_id hafd.block_id, _seq INT, _type SMALLINT)
RETURNS BIGINT
IMMUTABLE PARALLEL SAFE
LANGUAGE SQL AS $$
    SELECT (hafd.block_id_to_num(_block_id)::BIGINT << 32) | (_seq << 8) | _type;
$$;

COMMENT ON FUNCTION hafd.operation_id(hafd.block_id, INT, SMALLINT) IS 'Compute legacy operation_id from new (block_id, seq_in_block, op_type_id) columns';
