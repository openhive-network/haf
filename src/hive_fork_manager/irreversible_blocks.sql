CREATE TABLE IF NOT EXISTS hive.blocks (
       num integer NOT NULL,
       hash bytea NOT NULL,
       prev bytea NOT NULL,
       created_at timestamp without time zone NOT NULL,
       producer_account_id INTEGER NOT NULL,
       transaction_merkle_root bytea NOT NULL,
       extensions jsonb DEFAULT NULL,
       witness_signature bytea NOT NULL,
       signing_key text NOT NULL,
       CONSTRAINT pk_hive_blocks PRIMARY KEY( num )
);
SELECT pg_catalog.pg_extension_config_dump('hive.blocks', '');

CREATE TABLE IF NOT EXISTS hive.irreversible_data (
      id integer,
      consistent_block integer,
      is_dirty bool NOT NULL,
      CONSTRAINT pk_irreversible_data PRIMARY KEY ( id ),
      CONSTRAINT fk_1_hive_irreversible_data FOREIGN KEY (consistent_block) REFERENCES hive.blocks (num)
);

SELECT pg_catalog.pg_extension_config_dump('hive.irreversible_data', '');

CREATE TABLE IF NOT EXISTS hive.transactions (
    block_num integer NOT NULL,
    trx_in_block smallint NOT NULL,
    trx_hash bytea NOT NULL,
    ref_block_num integer NOT NULL,
    ref_block_prefix bigint NOT NULL,
    expiration timestamp without time zone NOT NULL,
    signature bytea DEFAULT NULL,
    CONSTRAINT pk_hive_transactions PRIMARY KEY ( trx_hash ),
    CONSTRAINT fk_1_hive_transactions FOREIGN KEY (block_num) REFERENCES hive.blocks (num)
);
SELECT pg_catalog.pg_extension_config_dump('hive.transactions', '');

CREATE TABLE IF NOT EXISTS hive.transactions_multisig (
    trx_hash bytea NOT NULL,
    signature bytea NOT NULL,
    CONSTRAINT pk_hive_transactions_multisig PRIMARY KEY ( trx_hash, signature ),
    CONSTRAINT fk_1_hive_transactions_multisig FOREIGN KEY (trx_hash) REFERENCES hive.transactions (trx_hash)
);
SELECT pg_catalog.pg_extension_config_dump('hive.transactions_multisig', '');

CREATE TABLE IF NOT EXISTS hive.operation_types (
    id smallint NOT NULL,
    name text NOT NULL,
    is_virtual boolean NOT NULL,
    CONSTRAINT pk_hive_operation_types PRIMARY KEY (id),
    CONSTRAINT uq_hive_operation_types UNIQUE (name)
);
SELECT pg_catalog.pg_extension_config_dump('hive.operation_types', '');

CREATE TABLE IF NOT EXISTS hive.operations (
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
    body text DEFAULT NULL,
    CONSTRAINT pk_hive_operations PRIMARY KEY ( id ),
    CONSTRAINT fk_1_hive_operations FOREIGN KEY (block_num) REFERENCES hive.blocks(num),
    CONSTRAINT fk_2_hive_operations FOREIGN KEY (op_type_id) REFERENCES hive.operation_types (id)
);
SELECT pg_catalog.pg_extension_config_dump('hive.operations', '');

CREATE TABLE IF NOT EXISTS hive.accounts (
      id INTEGER NOT NULL
    , name VARCHAR(16) NOT NULL
    , block_num INTEGER NOT NULL
    , CONSTRAINT pk_hive_accounts_id PRIMARY KEY( id )
    , CONSTRAINT uq_hive_accounst_name UNIQUE ( name )
    , CONSTRAINT fk_1_hive_accounts FOREIGN KEY (block_num) REFERENCES hive.blocks (num)
);
SELECT pg_catalog.pg_extension_config_dump('hive.accounts', '');

CREATE TABLE IF NOT EXISTS hive.account_operations
(
      block_num INTEGER NOT NULL
    , account_id INTEGER NOT NULL --- Identifier of account involved in given operation.
    , account_op_seq_no INTEGER NOT NULL --- Operation sequence number specific to given account.
    , operation_id BIGINT NOT NULL --- Id of operation held in hive_opreations table.
    , op_type_id SMALLINT NOT NULL --- The same as hive.operations.op_type_id. A redundant field is required due to performance.
    , CONSTRAINT hive_account_operations_fk_1 FOREIGN KEY (account_id) REFERENCES hive.accounts(id)
    , CONSTRAINT hive_account_operations_fk_2 FOREIGN KEY (operation_id) REFERENCES hive.operations(id)
    , CONSTRAINT hive_account_operations_fk_3 FOREIGN KEY (op_type_id) REFERENCES hive.operation_types (id)
    , CONSTRAINT hive_account_operations_uq_1 UNIQUE( account_id, account_op_seq_no )
    , CONSTRAINT hive_account_operations_uq2 UNIQUE ( account_id, operation_id )
);
SELECT pg_catalog.pg_extension_config_dump('hive.account_operations', '');

CREATE INDEX IF NOT EXISTS hive_transactions_block_num_trx_in_block_idx ON hive.transactions ( block_num, trx_in_block );

CREATE INDEX IF NOT EXISTS hive_operations_block_num_type_trx_in_block_idx ON hive.operations ( block_num, op_type_id, trx_in_block );
CREATE INDEX IF NOT EXISTS hive_operations_block_num_id_idx ON hive.operations USING btree(block_num, id);

CREATE UNIQUE INDEX IF NOT EXISTS hive_account_operations_type_account_id_op_seq_idx ON hive.account_operations( op_type_id, account_id, account_op_seq_no DESC ) INCLUDE( operation_id, block_num );
--CREATE INDEX IF NOT EXISTS hive_account_operations_account_id_op_seq_idx ON hive.account_operations( account_id, account_op_seq_no DESC ) INCLUDE( operation_id, block_num );
-- Commented out due to:
-- ERROR:  index "hive_account_operations_account_id_op_seq_idx" column number 2 does not have default sorting behavior
-- DETAIL:  Cannot create a primary key or unique constraint using such an index.
--ALTER TABLE hive.account_operations
--  ADD CONSTRAINT hive_account_operations_uq_1 UNIQUE USING INDEX hive_account_operations_account_id_op_seq_idx;

CREATE INDEX IF NOT EXISTS hive_accounts_block_num_idx ON hive.accounts USING btree (block_num);

CREATE INDEX IF NOT EXISTS hive_blocks_producer_account_id_idx ON hive.blocks (producer_account_id);
ALTER TABLE hive.blocks ADD CONSTRAINT fk_1_hive_blocks FOREIGN KEY (producer_account_id) REFERENCES hive.accounts (id) DEFERRABLE INITIALLY DEFERRED;

