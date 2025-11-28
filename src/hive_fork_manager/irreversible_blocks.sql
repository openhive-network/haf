CREATE DOMAIN hafd.vest_amount AS NUMERIC NOT NULL;
CREATE DOMAIN hafd.hive_amount AS NUMERIC NOT NULL;
CREATE DOMAIN hafd.hbd_amount AS NUMERIC NOT NULL;
--- Interest rate (in BPS - basis points)
CREATE DOMAIN hafd.interest_rate AS INT4 NOT NULL;

-- Helper functions for block_id encoding/decoding
-- block_id encoding: (num << 20) | fork_id
-- Upper 44 bits: block_num (max 17.6 trillion)
-- Lower 20 bits: fork_id (max 1M)

CREATE OR REPLACE FUNCTION hafd.block_id(num INT, fork_id BIGINT)
RETURNS BIGINT
LANGUAGE SQL
IMMUTABLE
AS
$$
    SELECT (num::BIGINT << 20) | fork_id;
$$;

CREATE OR REPLACE FUNCTION hafd.block_id_to_num(block_id BIGINT)
RETURNS INT
LANGUAGE SQL
IMMUTABLE
AS
$$
    SELECT (block_id >> 20)::INT;
$$;

CREATE OR REPLACE FUNCTION hafd.block_id_to_fork_id(block_id BIGINT)
RETURNS BIGINT
LANGUAGE SQL
IMMUTABLE
AS
$$
    SELECT block_id & 1048575; -- 0xFFFFF (20 bits)
$$;


CREATE TABLE IF NOT EXISTS hafd.blocks (
       num integer NOT NULL,
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

       fork_id BIGINT NOT NULL DEFAULT 0,
       block_id BIGINT NOT NULL GENERATED ALWAYS AS ((num::BIGINT << 20) | fork_id) STORED,

       CONSTRAINT pk_hive_blocks PRIMARY KEY( num, fork_id ),
       CONSTRAINT uq_hive_blocks_block_id UNIQUE (block_id),
       CONSTRAINT chk_hive_blocks_fork_id CHECK (fork_id < 1048576)
);
SELECT pg_catalog.pg_extension_config_dump('hafd.blocks', '');

CREATE STATISTICS IF NOT EXISTS blocks_num_hash_prev_dependency_stats (dependencies) ON num, hash, prev, created_at FROM hafd.blocks;

CREATE TYPE hafd.sync_state AS ENUM (
    'START', 'WAIT', 'REINDEX_WAIT', 'REINDEX', 'P2P', 'LIVE'
);


CREATE TABLE IF NOT EXISTS hafd.hive_state (
      id integer,
      consistent_block_id BIGINT,
      is_dirty bool NOT NULL,
      state hafd.sync_state NOT NULL DEFAULT 'START',
      pruning integer NOT NULL DEFAULT 0,
      CONSTRAINT pk_irreversible_data PRIMARY KEY ( id )
);

-- We use ADD CONSTRAINT with ALTER TABLE followed by NOT VALID because the NOT VALID option isn't documented
-- or supported within CREATE TABLE, and thus, seems not to work there.
-- This applies to the following tables as well.
ALTER TABLE hafd.hive_state ADD CONSTRAINT fk_1_hive_irreversible_data FOREIGN KEY (consistent_block_id) REFERENCES hafd.blocks (block_id) ON UPDATE CASCADE NOT VALID;
SELECT pg_catalog.pg_extension_config_dump('hafd.hive_state', '');

-- Reversible boundary table for partial index support
-- This table stores the block number boundary between irreversible and reversible blocks
-- It's updated automatically when consistent_block_id changes
CREATE TABLE IF NOT EXISTS hafd.reversible_boundary (
      id integer NOT NULL DEFAULT 1,
      boundary_block_num integer NOT NULL DEFAULT 0,
      CONSTRAINT pk_reversible_boundary PRIMARY KEY (id),
      CONSTRAINT single_row CHECK (id = 1)
);
SELECT pg_catalog.pg_extension_config_dump('hafd.reversible_boundary', '');

-- Initialize the boundary
INSERT INTO hafd.reversible_boundary (id, boundary_block_num) VALUES (1, 0) ON CONFLICT DO NOTHING;

-- Trigger function to update reversible_boundary when consistent_block_id changes
CREATE OR REPLACE FUNCTION hafd.update_reversible_boundary()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE hafd.reversible_boundary 
  SET boundary_block_num = hafd.block_id_to_num(COALESCE(NEW.consistent_block_id, 0))
  WHERE id = 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update the boundary
CREATE TRIGGER trg_update_reversible_boundary
AFTER UPDATE OF consistent_block_id ON hafd.hive_state
FOR EACH ROW
EXECUTE FUNCTION hafd.update_reversible_boundary();

CREATE TABLE IF NOT EXISTS hafd.transactions (
    block_id BIGINT NOT NULL,
    trx_in_block smallint NOT NULL,
    trx_hash bytea NOT NULL,
    ref_block_num integer NOT NULL,
    ref_block_prefix bigint NOT NULL,
    expiration timestamp without time zone NOT NULL,
    signature bytea DEFAULT NULL,
    CONSTRAINT pk_hive_transactions PRIMARY KEY ( trx_hash )
);
ALTER TABLE hafd.transactions ADD CONSTRAINT fk_1_hive_transactions FOREIGN KEY (block_id) REFERENCES hafd.blocks (block_id) NOT VALID;
SELECT pg_catalog.pg_extension_config_dump('hafd.transactions', '');
CREATE STATISTICS IF NOT EXISTS transactions_ref_block_dependency_stats (dependencies) ON ref_block_num, ref_block_prefix FROM hafd.transactions;


CREATE TABLE IF NOT EXISTS hafd.transactions_multisig (
    trx_hash bytea NOT NULL,
    signature bytea NOT NULL,
    CONSTRAINT pk_hive_transactions_multisig PRIMARY KEY ( trx_hash, signature )
);
-- ALTER TABLE hafd.transactions_multisig ADD CONSTRAINT fk_1_hive_transactions_multisig FOREIGN KEY (trx_hash) REFERENCES hafd.transactions (trx_hash) NOT VALID;
SELECT pg_catalog.pg_extension_config_dump('hafd.transactions_multisig', '');

CREATE TABLE IF NOT EXISTS hafd.operation_types (
    id smallint NOT NULL,
    name text NOT NULL,
    is_virtual boolean NOT NULL,
    CONSTRAINT pk_hive_operation_types PRIMARY KEY (id),
    CONSTRAINT uq_hive_operation_types UNIQUE (name)
);
SELECT pg_catalog.pg_extension_config_dump('hafd.operation_types', '');
CREATE STATISTICS IF NOT EXISTS operation_types_id_name_dependency_stats (dependencies) ON id, name FROM hafd.operation_types;

CREATE TABLE IF NOT EXISTS hafd.operations (
    -- id is encoded || 32b blocknum | 24b seq | 8b operation type ||
    id bigint not null,
    block_id BIGINT NOT NULL,
    trx_in_block smallint NOT NULL,
    op_pos integer NOT NULL,
    body_binary hafd.operation  DEFAULT NULL,
    CONSTRAINT pk_hive_operations PRIMARY KEY ( id )
);
ALTER TABLE hafd.operations ADD CONSTRAINT fk_1_hive_operations FOREIGN KEY (block_id) REFERENCES hafd.blocks (block_id) NOT VALID;

SELECT pg_catalog.pg_extension_config_dump('hafd.operations', '');

CREATE TABLE IF NOT EXISTS hafd.applied_hardforks (
    hardfork_num smallint NOT NULL,
    block_id BIGINT NOT NULL,
    hardfork_vop_id bigint NOT NULL,
    CONSTRAINT pk_hive_applied_hardforks PRIMARY KEY (hardfork_num)
);
ALTER TABLE hafd.applied_hardforks ADD CONSTRAINT fk_1_hive_applied_hardforks FOREIGN KEY (hardfork_vop_id) REFERENCES hafd.operations(id) NOT VALID;
ALTER TABLE hafd.applied_hardforks ADD CONSTRAINT fk_2_hive_applied_hardforks FOREIGN KEY (block_id) REFERENCES hafd.blocks(block_id) NOT VALID;
SELECT pg_catalog.pg_extension_config_dump('hafd.applied_hardforks', '');

CREATE STATISTICS IF NOT EXISTS applied_hardforks_hardfork_block_vop_dependency_stats (dependencies) ON hardfork_num, block_id, hardfork_vop_id FROM hafd.applied_hardforks;

CREATE TABLE IF NOT EXISTS hafd.accounts (
      id INTEGER NOT NULL
    , name VARCHAR(16) NOT NULL
    , block_id BIGINT
    , CONSTRAINT pk_hive_accounts_id PRIMARY KEY( id )
    , CONSTRAINT uq_hive_accounst_name UNIQUE ( name )
    
);
ALTER TABLE hafd.accounts ADD CONSTRAINT fk_1_hive_accounts FOREIGN KEY (block_id) REFERENCES hafd.blocks (block_id) MATCH FULL NOT VALID;
SELECT pg_catalog.pg_extension_config_dump('hafd.accounts', '');

CREATE STATISTICS IF NOT EXISTS accounts_id_name_blockid_dependency_stats (dependencies) ON id, name, block_id FROM hafd.accounts;

CREATE TABLE IF NOT EXISTS hafd.account_operations
(
      account_id INTEGER NOT NULL --- Identifier of account involved in given operation.
    , transacting_account_id INTEGER NOT NULL --- Identifier of account that performed the operation.
    , account_op_seq_no INTEGER NOT NULL --- Operation sequence number specific to given account.
    , operation_id BIGINT NOT NULL --- Id of operation held in hive_opreations table.
    , CONSTRAINT hive_account_operations_uq1 UNIQUE( account_id, account_op_seq_no )
    -- Hopefully not needed anymore, let's find out
    --, CONSTRAINT hive_account_operations_uq2 UNIQUE ( account,operation_id )
);
ALTER TABLE hafd.account_operations ADD CONSTRAINT hive_account_operations_fk_1 FOREIGN KEY (account_id) REFERENCES hafd.accounts(id) NOT VALID;
ALTER TABLE hafd.account_operations ADD CONSTRAINT hive_account_operations_fk_2 FOREIGN KEY (operation_id) REFERENCES hafd.operations(id) NOT VALID;
ALTER TABLE hafd.account_operations ADD CONSTRAINT hive_account_operations_fk_3 FOREIGN KEY (transacting_account_id) REFERENCES hafd.accounts(id) NOT VALID;
SELECT pg_catalog.pg_extension_config_dump('hafd.account_operations', '');


CREATE INDEX IF NOT EXISTS hive_applied_hardforks_block_id_idx ON hafd.applied_hardforks ( block_id );

CREATE INDEX IF NOT EXISTS hive_transactions_block_id_trx_in_block_idx ON hafd.transactions ( block_id, trx_in_block );

CREATE INDEX IF NOT EXISTS hive_operations_block_num_id_idx ON hafd.operations USING btree( hafd.operation_id_to_block_num(id), id);
CREATE INDEX IF NOT EXISTS hive_operations_block_num_trx_in_block_idx ON hafd.operations USING btree (hafd.operation_id_to_block_num(id) ASC NULLS LAST, trx_in_block ASC NULLS LAST, hafd.operation_id_to_type_id(id));
CREATE INDEX IF NOT EXISTS hive_operations_op_type_id_block_num ON hafd.operations (hafd.operation_id_to_type_id(id), hafd.operation_id_to_block_num(id));

--Clustering to speedup get_account_history queries (returns ordered set of operations for a specific account)
--Clustering takes 2 hours on a fast system with 4 maintenance works
--Clustering is actually done by hived, and the line below could technically be removed.
--Eventually we need functions on haf side to perform the clustering and make it part
--of adding indexes to the account_operations table to allow for more parallelism.
CLUSTER hafd.account_operations using hive_account_operations_uq1;

--This index is probably only needed for block_explorer queries right now, but maybe useful for other apps,
--so decided to add here rather than as part of hafbe as it isn't huge.
CREATE INDEX IF NOT EXISTS hive_account_operations_account_id_op_type_id_idx ON hafd.account_operations( account_id, hafd.operation_id_to_type_id(operation_id ) );

CREATE INDEX IF NOT EXISTS hive_accounts_block_id_idx ON hafd.accounts USING btree (block_id);

CREATE INDEX IF NOT EXISTS hive_blocks_producer_account_id_idx ON hafd.blocks (producer_account_id);
CREATE INDEX IF NOT EXISTS hive_blocks_created_at_idx ON hafd.blocks USING btree ( created_at );

ALTER TABLE hafd.blocks ADD CONSTRAINT fk_1_hive_blocks FOREIGN KEY (producer_account_id) REFERENCES hafd.accounts (id) NOT VALID DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE hafd.write_ahead_log_state (id SMALLINT NOT NULL UNIQUE CHECK (id = 1), last_sequence_number_committed INTEGER);
COMMENT ON TABLE hafd.write_ahead_log_state IS 'Tracks the sequence numbers in hived''s write-ahead log';
COMMENT ON COLUMN hafd.write_ahead_log_state.id IS 'an id column.  this table will never have more than one row, and its id will be 1.  an empty table is semantically equivalent to a table where the last_sequence_number_committed is NULL';
COMMENT ON COLUMN hafd.write_ahead_log_state.last_sequence_number_committed IS 'The sequence number of the last commited transaction, or NULL if we''re operating in a mode that doesn''t track sequence numbers.  Will always be non-negative';

SELECT pg_catalog.pg_extension_config_dump('hafd.write_ahead_log_state', '');

-- Partial indexes for reversible blocks
-- These indexes cover only the small reversible window at the head of the chain
-- They dramatically improve performance for queries on reversible data

-- Partial index on operations for reversible blocks
CREATE INDEX IF NOT EXISTS idx_operations_reversible_block_id 
ON hafd.operations ((block_id >> 20), (block_id & 1048575), block_id)
WHERE (block_id >> 20) > (SELECT boundary_block_num FROM hafd.reversible_boundary WHERE id = 1);

-- Partial index on transactions for reversible blocks  
CREATE INDEX IF NOT EXISTS idx_transactions_reversible_block_id
ON hafd.transactions ((block_id >> 20), (block_id & 1048575), block_id)
WHERE (block_id >> 20) > (SELECT boundary_block_num FROM hafd.reversible_boundary WHERE id = 1);

-- Partial index on accounts for reversible blocks
CREATE INDEX IF NOT EXISTS idx_accounts_reversible_block_id
ON hafd.accounts ((block_id >> 20), (block_id & 1048575), block_id)
WHERE (block_id >> 20) > (SELECT boundary_block_num FROM hafd.reversible_boundary WHERE id = 1);

-- Partial index on applied_hardforks for reversible blocks
CREATE INDEX IF NOT EXISTS idx_applied_hardforks_reversible_block_id
ON hafd.applied_hardforks ((block_id >> 20), (block_id & 1048575), block_id)
WHERE (block_id >> 20) > (SELECT boundary_block_num FROM hafd.reversible_boundary WHERE id = 1);
