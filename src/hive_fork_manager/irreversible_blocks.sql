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
-- Fork cleanup is done explicitly (fork switching is rare).

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

-- Optimized expression index for blocks_view canonical block selection
-- Uses fork_id only (not full block_id) since block_num is already in first column
-- This reduces index size by ~33% compared to using full block_id (~8 bytes/row vs ~12 bytes/row)
CREATE INDEX IF NOT EXISTS hive_blocks_block_num_idx ON hafd.blocks (
    hafd.block_id_to_num(block_id),
    hafd.block_id_to_fork(block_id) DESC
);

CREATE INDEX IF NOT EXISTS hive_blocks_producer_account_id_idx ON hafd.blocks (producer_account_id);

-- Timestamp index for queries that filter/sort blocks by created_at
-- (e.g. LATERAL joins in get_transaction_statistics, convert_to_block_num)
-- INCLUDE (block_id) enables Index Only Scan even with the block_conflicts
-- filter in blocks_view, avoiding heap access (~3.1 GB at 30M blocks)
CREATE INDEX IF NOT EXISTS hive_blocks_created_at_idx ON hafd.blocks USING btree ( created_at ) INCLUDE ( block_id );

CREATE STATISTICS IF NOT EXISTS blocks_block_num_stats ON (hafd.block_id_to_num(block_id)) FROM hafd.blocks;

-- =============================================================================
-- hafd.hive_state - System state tracking
-- =============================================================================

CREATE TYPE hafd.sync_state AS ENUM (
    'START', 'WAIT', 'REINDEX_WAIT', 'REINDEX', 'P2P', 'LIVE'
);

CREATE TABLE IF NOT EXISTS hafd.hive_state (
    id integer,
    consistent_block hafd.block_id,
    is_dirty bool NOT NULL,
    state hafd.sync_state NOT NULL DEFAULT 'START',
    pruning integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_irreversible_data PRIMARY KEY ( id )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.hive_state', '');

-- =============================================================================
-- hafd.block_conflicts - Tracks block_nums with multiple fork versions
-- =============================================================================
-- During LIVE mode, when a block arrives on a new fork while another version
-- already exists, that block_num is recorded here. Views can use this to
-- potentially skip canonical selection for non-conflicted blocks.
--
-- Size: Tiny (~200 rows max during active fork scenarios)
-- Updated by: hive.push_block() inserts, hive.remove_orphan_forks() deletes

CREATE TABLE IF NOT EXISTS hafd.block_conflicts (
    block_num INTEGER PRIMARY KEY
);
SELECT pg_catalog.pg_extension_config_dump('hafd.block_conflicts', '');

-- Check if a block_num has conflicts (multiple fork versions)
CREATE OR REPLACE FUNCTION hafd.block_conflicts_has(_block_num INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (SELECT 1 FROM hafd.block_conflicts WHERE block_num = _block_num);
$$;

-- =============================================================================
-- hafd.transactions - Original compact structure
-- =============================================================================

CREATE TABLE IF NOT EXISTS hafd.transactions (
    block_id hafd.block_id NOT NULL,
    trx_in_block smallint NOT NULL,
    trx_hash bytea NOT NULL,
    ref_block_num integer NOT NULL,
    ref_block_prefix bigint NOT NULL,
    expiration timestamp without time zone NOT NULL,
    signature bytea DEFAULT NULL,
    CONSTRAINT pk_hive_transactions PRIMARY KEY ( trx_hash, block_id )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.transactions', '');
CREATE STATISTICS IF NOT EXISTS transactions_ref_block_dependency_stats (dependencies) ON ref_block_num, ref_block_prefix FROM hafd.transactions;

-- =============================================================================
-- hafd.transactions_multisig - Original compact structure
-- =============================================================================

CREATE TABLE IF NOT EXISTS hafd.transactions_multisig (
    trx_hash bytea NOT NULL,
    signature bytea NOT NULL,
    block_id hafd.block_id NOT NULL,
    CONSTRAINT pk_hive_transactions_multisig PRIMARY KEY ( trx_hash, signature, block_id )
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

CREATE TABLE IF NOT EXISTS hafd.custom_json_types (
    id SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    custom_json_id VARCHAR(32) NOT NULL UNIQUE
);
SELECT pg_catalog.pg_extension_config_dump('hafd.custom_json_types', '');
CREATE STATISTICS IF NOT EXISTS operation_types_id_name_dependency_stats (dependencies) ON id, name FROM hafd.operation_types;

-- =============================================================================
-- hafd.operations - Original compact structure with encoded id
-- =============================================================================
-- id is encoded || 32b block_num | 32b pos_in_block ||
-- This compact encoding minimizes data volume during massive sync.
-- No FK to blocks - fork cleanup is done explicitly (rare operation).
-- op_type_id is stored as a separate column (not encoded in id).

CREATE TABLE IF NOT EXISTS hafd.operations (
    block_id hafd.block_id NOT NULL,
    trx_in_block smallint NOT NULL,
    op_type_id smallint NOT NULL,
    op_pos integer NOT NULL,
    body_binary hafd.operation DEFAULT NULL,
    -- id is pre-computed in C++ for massive sync performance
    -- Encoding: (block_num << 32) | pos_in_block
    id BIGINT NOT NULL,
    CONSTRAINT pk_hive_operations PRIMARY KEY ( block_id, id )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.operations', '');

-- =============================================================================
-- hafd.applied_hardforks - Original compact structure
-- =============================================================================

CREATE TABLE IF NOT EXISTS hafd.applied_hardforks (
    hardfork_num smallint NOT NULL,
    block_id hafd.block_id NOT NULL,
    hardfork_vop_id bigint NOT NULL,
    CONSTRAINT pk_hive_applied_hardforks PRIMARY KEY (hardfork_num, block_id)
);
SELECT pg_catalog.pg_extension_config_dump('hafd.applied_hardforks', '');

CREATE STATISTICS IF NOT EXISTS applied_hardforks_hardfork_block_vop_dependency_stats (dependencies) ON hardfork_num, block_id, hardfork_vop_id FROM hafd.applied_hardforks;

-- =============================================================================
-- hafd.accounts - Original compact structure
-- block_id IS NULL means account was dumped at startup (psql-first-block > 1)
-- Same account can exist on different forks (different block_id values)
-- NULLS NOT DISTINCT ensures only one (id, NULL) row per account
-- =============================================================================

CREATE TABLE IF NOT EXISTS hafd.accounts (
    id INTEGER NOT NULL,
    name VARCHAR(16) NOT NULL,
    block_id hafd.block_id,
    CONSTRAINT uq_hive_accounts UNIQUE NULLS NOT DISTINCT (id, block_id)
);
SELECT pg_catalog.pg_extension_config_dump('hafd.accounts', '');

CREATE STATISTICS IF NOT EXISTS accounts_id_name_blocknum_dependency_stats (dependencies) ON id, name, block_id FROM hafd.accounts;

-- =============================================================================
-- hafd.account_operations - Account to operation mapping with operation_id
-- =============================================================================
-- Stores operation_id directly to avoid JOIN with operations table in views.
-- This is critical for get_account_history performance.
-- No FK CASCADE - fork cleanup is done explicitly (rare operation).

CREATE TABLE IF NOT EXISTS hafd.account_operations (
    account_id INTEGER NOT NULL,
    transacting_account_id INTEGER NOT NULL,
    account_op_seq_no INTEGER NOT NULL,
    block_id hafd.block_id NOT NULL,
    operation_id BIGINT NOT NULL,
    op_type_id smallint NOT NULL,
    CONSTRAINT hive_account_operations_uq1 UNIQUE( account_id, account_op_seq_no, block_id )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.account_operations', '');

-- =============================================================================
-- Indexes - Original structure
-- =============================================================================

CREATE INDEX IF NOT EXISTS hive_applied_hardforks_block_num_idx ON hafd.applied_hardforks ( block_id );

-- Optimized expression index for transactions_view canonical block selection
-- Uses fork_id only (not full block_id) since block_num is already in first column
-- This reduces index size by ~28% compared to using full block_id (~10 bytes/row vs ~14 bytes/row)
CREATE INDEX IF NOT EXISTS hive_transactions_block_id_to_num_idx ON hafd.transactions (
    hafd.block_id_to_num(block_id),
    trx_in_block,
    hafd.block_id_to_fork(block_id) DESC
);

CREATE INDEX IF NOT EXISTS hive_operations_block_num_trx_in_block_idx ON hafd.operations USING btree (hafd.operation_id_to_block_num(id) ASC NULLS LAST, trx_in_block ASC NULLS LAST, op_type_id);

-- Index for operations_view canonical selection: finds highest block_id per (block_num, pos_in_block)
-- id encodes (block_num|pos), so same id = same operation across forks
CREATE INDEX IF NOT EXISTS hive_operations_id_block_id_idx ON hafd.operations (id, block_id DESC);

-- Index for id-only lookups when PK is (block_id, id)
CREATE INDEX IF NOT EXISTS hive_operations_id_idx ON hafd.operations (id);

-- BRIN indexes for efficient range scans during batch joins in context views.
-- With pages_per_range=16, these are tiny (<1 MB) but dramatically speed up
-- range-bounded queries like "block_id BETWEEN X AND Y" that are common in
-- non-forking/all-irreversible views during massive sync.
CREATE INDEX IF NOT EXISTS hive_transactions_block_id_brin ON hafd.transactions USING BRIN (block_id) WITH (pages_per_range = 16);
CREATE INDEX IF NOT EXISTS hive_operations_block_id_brin ON hafd.operations USING BRIN (block_id) WITH (pages_per_range = 16);

-- Clustering for get_account_history performance
CLUSTER hafd.account_operations USING hive_account_operations_uq1;

CREATE INDEX IF NOT EXISTS hive_accounts_name_idx ON hafd.accounts USING btree (name);

-- =============================================================================
-- hafd.write_ahead_log_state - WAL tracking (unchanged)
-- =============================================================================

CREATE TABLE hafd.write_ahead_log_state (id SMALLINT NOT NULL UNIQUE CHECK (id = 1), last_sequence_number_committed INTEGER);
COMMENT ON TABLE hafd.write_ahead_log_state IS 'Tracks the sequence numbers in hived''s write-ahead log';
COMMENT ON COLUMN hafd.write_ahead_log_state.id IS 'an id column.  this table will never have more than one row, and its id will be 1.  an empty table is semantically equivalent to a table where the last_sequence_number_committed is NULL';
COMMENT ON COLUMN hafd.write_ahead_log_state.last_sequence_number_committed IS 'The sequence number of the last commited transaction, or NULL if we''re operating in a mode that doesn''t track sequence numbers.  Will always be non-negative';

SELECT pg_catalog.pg_extension_config_dump('hafd.write_ahead_log_state', '');
