CREATE TABLE IF NOT EXISTS hafd.blocks_reversible(
    LIKE hafd.blocks INCLUDING ALL
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
SELECT pg_catalog.pg_extension_config_dump('hafd.blocks_reversible', '');
ALTER TABLE hafd.blocks_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_hive_blocks_reversible PRIMARY KEY( num, fork_id ),
    ADD CONSTRAINT fk_1_hive_blocks_reversible FOREIGN KEY( fork_id ) REFERENCES hafd.fork( id )
;

CREATE TABLE IF NOT EXISTS hafd.transactions_reversible(
    LIKE hafd.transactions
    INCLUDING ALL
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
SELECT pg_catalog.pg_extension_config_dump('hafd.transactions_reversible', '');
ALTER TABLE hafd.transactions_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT fk_1_hive_transactions_reversible FOREIGN KEY (block_num, fork_id) REFERENCES hafd.blocks_reversible(num,fork_id),
    ADD CONSTRAINT uq_hive_transactions_reversible PRIMARY KEY( trx_hash, fork_id )
;

CREATE TABLE IF NOT EXISTS hafd.transactions_multisig_reversible(
    LIKE hafd.transactions_multisig
    INCLUDING ALL
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
SELECT pg_catalog.pg_extension_config_dump('hafd.transactions_multisig_reversible', '');
ALTER TABLE hafd.transactions_multisig_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_transactions_multisig_reversible PRIMARY KEY ( trx_hash, signature, fork_id ),
    ADD CONSTRAINT fk_1_hive_transactions_multisig_reversible FOREIGN KEY (trx_hash, fork_id) REFERENCES hafd.transactions_reversible(trx_hash, fork_id)
;

CREATE TABLE IF NOT EXISTS hafd.operations_reversible(
    LIKE hafd.operations
    INCLUDING ALL
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
SELECT pg_catalog.pg_extension_config_dump('hafd.operations_reversible', '');
ALTER TABLE hafd.operations_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_operations_reversible PRIMARY KEY( id, fork_id ),
    ADD CONSTRAINT uq_operations_reversible UNIQUE( id, fork_id )
    --ADD CONSTRAINT fk_1_hive_operations_reversible FOREIGN KEY (block_num, fork_id) REFERENCES hafd.blocks_reversible(num, fork_id),
    --ADD CONSTRAINT fk_2_hive_operations_reversible FOREIGN KEY (op_type_id) REFERENCES hafd.operation_types (id)
;

CREATE TABLE IF NOT EXISTS hafd.accounts_reversible(
    LIKE hafd.accounts
    INCLUDING ALL
    EXCLUDING CONSTRAINTS -- because of UNIQUE(name)
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
SELECT pg_catalog.pg_extension_config_dump('hafd.accounts_reversible', '');
ALTER TABLE hafd.accounts_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_hive_accounts_reversible_id PRIMARY KEY( id, fork_id ),
    ADD CONSTRAINT fk_1_hive_accounts_reversible FOREIGN KEY ( block_num, fork_id ) REFERENCES hafd.blocks_reversible( num, fork_id ),
    ADD CONSTRAINT uq_hive_accounts_reversible UNIQUE( name, fork_id )
;

CREATE TABLE IF NOT EXISTS hafd.account_operations_reversible(
    LIKE hafd.account_operations
    INCLUDING ALL
    EXCLUDING CONSTRAINTS -- because of unique(account_id, account_op_seq_no) and (account_id, operation_id)
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
)
;
SELECT pg_catalog.pg_extension_config_dump('hafd.account_operations_reversible', '');
ALTER TABLE hafd.account_operations_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT fk_1_hive_account_operations_reversible FOREIGN KEY ( operation_id, fork_id ) REFERENCES hafd.operations_reversible( id, fork_id ),
    ADD CONSTRAINT pk_hive_account_operations_reversible PRIMARY KEY( account_id, account_op_seq_no, transacting_account_id, fork_id )
;

CREATE TABLE IF NOT EXISTS hafd.applied_hardforks_reversible(
    LIKE hafd.applied_hardforks
    INCLUDING ALL
    EXCLUDING CONSTRAINTS
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
SELECT pg_catalog.pg_extension_config_dump('hafd.applied_hardforks_reversible', '');
ALTER TABLE hafd.applied_hardforks_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_hive_applied_hardforks_reversible PRIMARY KEY( hardfork_num, fork_id ),
    ADD CONSTRAINT fk_1_hive_applied_hardforks_reversible FOREIGN KEY ( block_num, fork_id ) REFERENCES hafd.blocks_reversible( num, fork_id )

;

CREATE INDEX IF NOT EXISTS hive_applied_hardforks_reversible_block_num_idx ON hafd.applied_hardforks_reversible( block_num );
CREATE INDEX IF NOT EXISTS hive_applied_hardforks_reversible_fork_id_idx ON hafd.applied_hardforks_reversible( fork_id );
CREATE INDEX IF NOT EXISTS hive_transactions_reversible_block_num_trx_in_block_fork_id_idx ON hafd.transactions_reversible( block_num, trx_in_block, fork_id );
CREATE INDEX IF NOT EXISTS hive_operations_reversible_block_num_type_id_trx_in_block_fork_id_idx ON hafd.operations_reversible( hafd.operation_id_to_block_num(id), hafd.operation_id_to_type_id(id), trx_in_block, fork_id );
CREATE INDEX IF NOT EXISTS hive_operations_reversible_block_num_id_idx ON hafd.operations_reversible USING btree(hafd.operation_id_to_block_num(id), id, fork_id);
CREATE INDEX IF NOT EXISTS hive_account_operations_reversible_operation_id_idx ON hafd.account_operations_reversible(operation_id, fork_id);
CREATE INDEX IF NOT EXISTS hive_account_operations_reversible_type_account_id_op_seq_idx ON hafd.account_operations_reversible( hafd.operation_id_to_type_id( operation_id ), account_id, account_op_seq_no DESC, transacting_account_id, operation_id, hafd.operation_id_to_block_num(operation_id) );

