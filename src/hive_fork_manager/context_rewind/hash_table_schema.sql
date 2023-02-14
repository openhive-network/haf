CREATE TABLE IF NOT EXISTS hash.blocks (
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

       hbd_interest_rate hive.interest_rate,

       total_vesting_fund_hive hive.hive_amount,
       total_vesting_shares hive.vest_amount,

       total_reward_fund_hive hive.hive_amount,
       
       virtual_supply hive.hive_amount,
       current_supply hive.hive_amount,

       current_hbd_supply hive.hbd_amount,
       dhf_interval_ledger hive.hbd_amount,

       CONSTRAINT pk_hive_blocks PRIMARY KEY( num )
);

CREATE TABLE IF NOT EXISTS hash.irreversible_data (
      id integer,
      consistent_block integer,
      is_dirty bool NOT NULL,
      CONSTRAINT pk_irreversible_data PRIMARY KEY ( id ),
      CONSTRAINT fk_1_hive_irreversible_data FOREIGN KEY (consistent_block) REFERENCES hash.blocks (num)
);

CREATE TABLE IF NOT EXISTS hash.transactions (
    block_num integer NOT NULL,
    trx_in_block smallint NOT NULL,
    trx_hash bytea NOT NULL,
    ref_block_num integer NOT NULL,
    ref_block_prefix bigint NOT NULL,
    expiration timestamp without time zone NOT NULL,
    signature bytea DEFAULT NULL,
    CONSTRAINT pk_hive_transactions PRIMARY KEY ( trx_hash ),
    CONSTRAINT fk_1_hive_transactions FOREIGN KEY (block_num) REFERENCES hash.blocks (num)
);

CREATE TABLE IF NOT EXISTS hash.transactions_multisig (
    trx_hash bytea NOT NULL,
    signature bytea NOT NULL,
    CONSTRAINT pk_hive_transactions_multisig PRIMARY KEY ( trx_hash, signature ),
    CONSTRAINT fk_1_hive_transactions_multisig FOREIGN KEY (trx_hash) REFERENCES hash.transactions (trx_hash)
);

CREATE TABLE IF NOT EXISTS hash.operation_types (
    id smallint NOT NULL,
    name text NOT NULL,
    is_virtual boolean NOT NULL,
    CONSTRAINT pk_hive_operation_types PRIMARY KEY (id),
    CONSTRAINT uq_hive_operation_types UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS hash.operations (
    id bigint not null,
    block_num integer NOT NULL,
    trx_in_block smallint NOT NULL,
    op_pos integer NOT NULL,
    op_type_id smallint NOT NULL,
    -- timestamp: Specific to operation kind.  It may be set for block time -3s (current hived head_block_time)
    -- or for **next**  block time (when hived node finished evaluation of current block).
    -- This behavior depends on hived implementation, and **this logic should not be** repeated HAF-client app side. Specifically:
    -- - regular user operations put into transactions got head_block_time: -3s ( time of block predecessing currently applied block )
    -- - fork and schedule operations got head_block_time: -3s ( time of block predecessing currently applied block )
    -- - system triggered virtual operations usualy are created after applaying current block and got time equals its time
    --   (after hived not changed head_block to another one)
    timestamp TIMESTAMP NOT NULL,
    body hive.operation DEFAULT NULL,
    CONSTRAINT pk_hive_operations PRIMARY KEY ( id ),
    CONSTRAINT fk_1_hive_operations FOREIGN KEY (block_num) REFERENCES hash.blocks(num),
    CONSTRAINT fk_2_hive_operations FOREIGN KEY (op_type_id) REFERENCES hash.operation_types (id)
);

CREATE TABLE IF NOT EXISTS hash.applied_hardforks (
    hardfork_num smallint NOT NULL,
    block_num integer NOT NULL,
    hardfork_vop_id bigint NOT NULL,
    CONSTRAINT pk_hive_applied_hardforks PRIMARY KEY (hardfork_num),
    CONSTRAINT fk_1_hive_applied_hardforks FOREIGN KEY (hardfork_vop_id) REFERENCES hash.operations(id),
    CONSTRAINT fk_2_hive_applied_hardforks FOREIGN KEY (block_num) REFERENCES hash.blocks(num)
);

CREATE TABLE IF NOT EXISTS hash.accounts (
      id INTEGER NOT NULL
    , name VARCHAR(16) NOT NULL
    , block_num INTEGER NOT NULL
    , CONSTRAINT pk_hive_accounts_id PRIMARY KEY( id )
    , CONSTRAINT uq_hive_accounst_name UNIQUE ( name )
    , CONSTRAINT fk_1_hive_accounts FOREIGN KEY (block_num) REFERENCES hash.blocks (num)
);


CREATE TABLE IF NOT EXISTS hash.account_operations
(
      block_num INTEGER NOT NULL
    , account_id INTEGER NOT NULL --- Identifier of account involved in given operation.
    , account_op_seq_no INTEGER NOT NULL --- Operation sequence number specific to given account.
    , operation_id BIGINT NOT NULL --- Id of operation held in hive_opreations table.
    , op_type_id SMALLINT NOT NULL --- The same as hive.operations.op_type_id. A redundant field is required due to performance.
    , CONSTRAINT hive_account_operations_fk_1 FOREIGN KEY (account_id) REFERENCES hash.accounts(id)
    , CONSTRAINT hive_account_operations_fk_2 FOREIGN KEY (operation_id) REFERENCES hash.operations(id)
    , CONSTRAINT hive_account_operations_fk_3 FOREIGN KEY (op_type_id) REFERENCES hash.operation_types (id)
    , CONSTRAINT hive_account_operations_uq_1 UNIQUE( account_id, account_op_seq_no )
    , CONSTRAINT hive_account_operations_uq2 UNIQUE ( account_id, operation_id )
);

CREATE TABLE IF NOT EXISTS hash.fork(
    id BIGSERIAL NOT NULL,
    block_num INT NOT NULL, -- head block number, after reverting all blocks from fork (look for `notify_switch_fork` in database.cpp hive project file )
    time_of_fork TIMESTAMP WITHOUT TIME ZONE NOT NULL, -- time of receiving notification from hived (see: hive.back_from_fork definition)
    CONSTRAINT pk_hive_fork PRIMARY KEY( id )
);


CREATE TABLE IF NOT EXISTS hash.blocks_reversible(
    LIKE hash.blocks INCLUDING ALL
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
ALTER TABLE hash.blocks_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_hive_blocks_reversible PRIMARY KEY( num, fork_id ),
    ADD CONSTRAINT fk_1_hive_blocks_reversible FOREIGN KEY( fork_id ) REFERENCES hash.fork( id );

CREATE TABLE IF NOT EXISTS hash.transactions_reversible(
    LIKE hash.transactions
    INCLUDING ALL
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
ALTER TABLE hash.transactions_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT fk_1_hive_transactions_reversible FOREIGN KEY (block_num, fork_id) REFERENCES hash.blocks_reversible(num,fork_id),
    ADD CONSTRAINT uq_hive_transactions_reversible PRIMARY KEY( trx_hash, fork_id );

CREATE TABLE IF NOT EXISTS hash.transactions_multisig_reversible(
    LIKE hash.transactions_multisig
    INCLUDING ALL
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
ALTER TABLE hash.transactions_multisig_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_transactions_multisig_reversible PRIMARY KEY ( trx_hash, signature, fork_id ),
    ADD CONSTRAINT fk_1_hive_transactions_multisig_reversible FOREIGN KEY (trx_hash, fork_id) REFERENCES hash.transactions_reversible(trx_hash, fork_id);

CREATE TABLE IF NOT EXISTS hash.operations_reversible(
    LIKE hash.operations
    INCLUDING ALL
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
ALTER TABLE hash.operations_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_operations_reversible PRIMARY KEY( id, block_num, fork_id ),
    ADD CONSTRAINT uq_operations_reversible UNIQUE( id, fork_id ),
    ADD CONSTRAINT fk_1_hive_operations_reversible FOREIGN KEY (block_num, fork_id) REFERENCES hash.blocks_reversible(num, fork_id),
    ADD CONSTRAINT fk_2_hive_operations_reversible FOREIGN KEY (op_type_id) REFERENCES hash.operation_types (id);

CREATE TABLE IF NOT EXISTS hash.accounts_reversible(
    LIKE hash.accounts
    INCLUDING ALL
    EXCLUDING CONSTRAINTS -- because of UNIQUE(name)
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
ALTER TABLE hash.accounts_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_hive_accounts_reversible_id PRIMARY KEY( id, fork_id ),
    ADD CONSTRAINT fk_1_hive_accounts_reversible FOREIGN KEY ( block_num, fork_id ) REFERENCES hash.blocks_reversible( num, fork_id ),
    ADD CONSTRAINT uq_hive_accounts_reversible UNIQUE( name, fork_id );

CREATE TABLE IF NOT EXISTS hash.account_operations_reversible(
    LIKE hash.account_operations
    INCLUDING ALL
    EXCLUDING CONSTRAINTS -- because of unique(account_id, account_op_seq_no) and (account_id, operation_id)
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
ALTER TABLE hash.account_operations_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT fk_1_hive_account_operations_reversible FOREIGN KEY ( operation_id, fork_id ) REFERENCES hash.operations_reversible( id, fork_id ),
    ADD CONSTRAINT pk_hive_account_operations_reversible PRIMARY KEY( account_id, account_op_seq_no, fork_id );

CREATE TABLE IF NOT EXISTS hash.applied_hardforks_reversible(
    LIKE hash.applied_hardforks
    INCLUDING ALL
    EXCLUDING CONSTRAINTS
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
ALTER TABLE hash.applied_hardforks_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_hive_applied_hardforks_reversible PRIMARY KEY( hardfork_num, fork_id ),
    ADD CONSTRAINT fk_1_hive_applied_hardforks_reversible FOREIGN KEY ( block_num, fork_id ) REFERENCES hash.blocks_reversible( num, fork_id );

CREATE TABLE IF NOT EXISTS hash.contexts(
    id SERIAL NOT NULL,
    name hive.context_name NOT NULL,
    current_block_num INTEGER NOT NULL,
    irreversible_block INTEGER NOT NULL,
    is_attached BOOL NOT NULL,
    back_from_fork BOOL NOT NULL DEFAULT FALSE,
    events_id BIGINT NOT NULL DEFAULT 0, -- 0 - is a special fake event, means no events are processed, it is required to satisfy FK constraint
    fork_id BIGINT NOT NULL DEFAULT 1,
    owner NAME NOT NULL,
    detached_block_num INTEGER, -- place where application can save last processed block num in detached state
    registering_state_provider BOOL NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_hive_contexts PRIMARY KEY( id ),
    CONSTRAINT uq_hive_context_name UNIQUE ( name )
);

CREATE INDEX IF NOT EXISTS hive_contexts_owner_idx ON hash.contexts( owner );

CREATE TABLE IF NOT EXISTS hash.events_queue(
      id BIGSERIAL PRIMARY KEY
    , event hive.event_type NOT NULL
    , block_num BIGINT NOT NULL
);

ALTER TABLE hash.contexts
ADD CONSTRAINT fk_hive_app_context FOREIGN KEY(events_id) REFERENCES hash.events_queue( id ),
ADD CONSTRAINT fk_2_hive_app_context FOREIGN KEY(fork_id) REFERENCES hash.fork( id );

CREATE INDEX IF NOT EXISTS hive_events_queue_block_num_idx ON hash.events_queue( block_num );

CREATE TABLE IF NOT EXISTS hash.hived_connections(
    id BIGSERIAL NOT NULL,
    block_num INT NOT NULL,
    git_sha TEXT,
    time TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    CONSTRAINT pk_hived_connections PRIMARY KEY( id )
);

CREATE TABLE IF NOT EXISTS hash.indexes_constraints (
    table_name text NOT NULL,
    index_constraint_name text NOT NULL,
    command text NOT NULL,
    is_constraint boolean NOT NULL,
    is_index boolean NOT NULL,
    is_foreign_key boolean NOT NULL,
    CONSTRAINT pk_hive_indexes_constraints UNIQUE( table_name, index_constraint_name )
);

CREATE TABLE IF NOT EXISTS hash.registered_tables(
   id SERIAL NOT NULL,
   context_id INTEGER NOT NULL,
   origin_table_schema TEXT NOT NULL,
   origin_table_name TEXT NOT NULL,
   shadow_table_name TEXT NOT NULL,
   origin_table_columns TEXT[] NOT NULL,
   owner NAME NOT NULL,
   CONSTRAINT pk_hive_registered_tables PRIMARY KEY( id ),
   CONSTRAINT fk_hive_registered_tables_context FOREIGN KEY(context_id) REFERENCES hash.contexts( id ),
   CONSTRAINT uq_hive_registered_tables_register_table UNIQUE( origin_table_schema, origin_table_name )
);

CREATE INDEX IF NOT EXISTS hive_registered_tables_context_idx ON hash.registered_tables( context_id );
CREATE INDEX IF NOT EXISTS hive_registered_tables_owder_idx ON hash.registered_tables( owner );

CREATE TABLE IF NOT EXISTS hash.state_providers_registered(
      id SERIAL
    , context_id INTEGER NOT NULL
    , state_provider HIVE.STATE_PROVIDERS NOT NULL
    , tables TEXT[] NOT NULL
    , owner NAME NOT NULL
    , CONSTRAINT pk_hive_state_providers_registered PRIMARY KEY( id )
    , CONSTRAINT uq_hive_state_providers_registered_contexts_provider  UNIQUE ( context_id, state_provider )
    , CONSTRAINT fk_hive_state_providers_registered_context FOREIGN KEY( context_id ) REFERENCES hash.contexts( id )
);

CREATE INDEX IF NOT EXISTS hive_state_providers_registered_idx ON hash.state_providers_registered( owner );

CREATE TABLE IF NOT EXISTS hash.triggers(
   id SERIAL PRIMARY KEY,
   registered_table_id INTEGER NOT NULL,
   trigger_name TEXT NOT NULL,
   function_name TEXT NOT NULL,
   owner NAME NOT NULL,
   CONSTRAINT fk_hive_triggers_registered_table FOREIGN KEY( registered_table_id ) REFERENCES hash.registered_tables( id ),
   CONSTRAINT uq_hive_triggers_registered_table UNIQUE( trigger_name )
);

CREATE INDEX IF NOT EXISTS hive_registered_triggers_table_id ON hash.triggers( registered_table_id );
CREATE INDEX IF NOT EXISTS hive_triggers_owner_idx ON hash.triggers( owner );


CREATE INDEX IF NOT EXISTS hive_applied_hardforks_reversible_block_num_idx ON hash.applied_hardforks_reversible( block_num );
CREATE INDEX IF NOT EXISTS hive_applied_hardforks_reversible_fork_id_idx ON hash.applied_hardforks_reversible( fork_id );
CREATE INDEX IF NOT EXISTS hive_transactions_reversible_block_num_trx_in_block_fork_id_idx ON hash.transactions_reversible( block_num, trx_in_block, fork_id );
CREATE INDEX IF NOT EXISTS hive_operations_reversible_block_num_type_id_trx_in_block_fork_id_idx ON hash.operations_reversible( block_num, op_type_id, trx_in_block, fork_id );
CREATE INDEX IF NOT EXISTS hive_operations_reversible_block_num_id_idx ON hash.operations_reversible USING btree(block_num, id, fork_id);
CREATE INDEX IF NOT EXISTS hive_account_operations_reversible_operation_id_idx ON hash.account_operations_reversible(operation_id, fork_id);
CREATE INDEX IF NOT EXISTS hive_account_operations_reversible_type_account_id_op_seq_idx ON hash.account_operations_reversible( op_type_id, account_id, account_op_seq_no DESC ) INCLUDE( operation_id, block_num );

CREATE INDEX IF NOT EXISTS hive_applied_hardforks_block_num_idx ON hash.applied_hardforks ( block_num );
CREATE INDEX IF NOT EXISTS hive_transactions_block_num_trx_in_block_idx ON hash.transactions ( block_num, trx_in_block );
CREATE INDEX IF NOT EXISTS hive_operations_block_num_id_idx ON hash.operations USING btree(block_num, id);
CREATE INDEX IF NOT EXISTS hive_operations_block_num_trx_in_block_idx ON hash.operations USING btree (block_num ASC NULLS LAST, trx_in_block ASC NULLS LAST) INCLUDE (op_type_id);
CREATE INDEX IF NOT EXISTS hive_operations_op_type_id ON hash.operations USING btree (op_type_id);
CREATE UNIQUE INDEX IF NOT EXISTS hive_account_operations_type_account_id_op_seq_idx ON hash.account_operations( op_type_id, account_id, account_op_seq_no DESC ) INCLUDE( operation_id, block_num );
--CREATE INDEX IF NOT EXISTS hive_account_operations_account_id_op_seq_idx ON hive.account_operations( account_id, account_op_seq_no DESC ) INCLUDE( operation_id, block_num );
-- Commented out due to:
-- ERROR:  index "hive_account_operations_account_id_op_seq_idx" column number 2 does not have default sorting behavior
-- DETAIL:  Cannot create a primary key or unique constraint using such an index.
--ALTER TABLE hive.account_operations
--  ADD CONSTRAINT hive_account_operations_uq_1 UNIQUE USING INDEX hive_account_operations_account_id_op_seq_idx;
CREATE INDEX IF NOT EXISTS hive_accounts_block_num_idx ON hash.accounts USING btree (block_num);
CREATE INDEX IF NOT EXISTS hive_blocks_producer_account_id_idx ON hash.blocks (producer_account_id);
CREATE INDEX IF NOT EXISTS hive_blocks_created_at_idx ON hash.blocks USING btree ( created_at );
ALTER TABLE hash.blocks ADD CONSTRAINT fk_1_hive_blocks FOREIGN KEY (producer_account_id) REFERENCES hash.accounts (id) DEFERRABLE INITIALLY DEFERRED;
