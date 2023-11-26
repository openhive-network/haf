CREATE UNLOGGED TABLE IF NOT EXISTS hive.blocks_reversible(
    LIKE hive.blocks INCLUDING ALL
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
SELECT pg_catalog.pg_extension_config_dump('hive.blocks_reversible', '');
ALTER TABLE hive.blocks_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_hive_blocks_reversible PRIMARY KEY( num, fork_id ),
    ADD CONSTRAINT fk_1_hive_blocks_reversible FOREIGN KEY( fork_id ) REFERENCES hive.fork( id )
;

CREATE UNLOGGED TABLE IF NOT EXISTS hive.transactions_reversible(
    LIKE hive.transactions
    INCLUDING ALL
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
SELECT pg_catalog.pg_extension_config_dump('hive.transactions_reversible', '');
ALTER TABLE hive.transactions_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT fk_1_hive_transactions_reversible FOREIGN KEY (block_num, fork_id) REFERENCES hive.blocks_reversible(num,fork_id),
    ADD CONSTRAINT uq_hive_transactions_reversible PRIMARY KEY( trx_hash, fork_id )
;

CREATE UNLOGGED TABLE IF NOT EXISTS hive.transactions_multisig_reversible(
    LIKE hive.transactions_multisig
    INCLUDING ALL
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
SELECT pg_catalog.pg_extension_config_dump('transactions_multisig_reversible', '');
ALTER TABLE hive.transactions_multisig_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_transactions_multisig_reversible PRIMARY KEY ( trx_hash, signature, fork_id ),
    ADD CONSTRAINT fk_1_hive_transactions_multisig_reversible FOREIGN KEY (trx_hash, fork_id) REFERENCES hive.transactions_reversible(trx_hash, fork_id)
;

CREATE UNLOGGED TABLE IF NOT EXISTS hive.operations_reversible(
    LIKE hive.operations
    INCLUDING ALL
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
SELECT pg_catalog.pg_extension_config_dump('operations_reversible', '');
ALTER TABLE hive.operations_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_operations_reversible PRIMARY KEY( id, block_num, fork_id ),
    ADD CONSTRAINT uq_operations_reversible UNIQUE( id, fork_id ),
    ADD CONSTRAINT fk_1_hive_operations_reversible FOREIGN KEY (block_num, fork_id) REFERENCES hive.blocks_reversible(num, fork_id),
    ADD CONSTRAINT fk_2_hive_operations_reversible FOREIGN KEY (op_type_id) REFERENCES hive.operation_types (id)
;

CREATE UNLOGGED TABLE IF NOT EXISTS hive.accounts_reversible(
    LIKE hive.accounts
    INCLUDING ALL
    EXCLUDING CONSTRAINTS -- because of UNIQUE(name)
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
SELECT pg_catalog.pg_extension_config_dump('accounts_reversible', '');
ALTER TABLE hive.accounts_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_hive_accounts_reversible_id PRIMARY KEY( id, fork_id ),
    ADD CONSTRAINT fk_1_hive_accounts_reversible FOREIGN KEY ( block_num, fork_id ) REFERENCES hive.blocks_reversible( num, fork_id ),
    ADD CONSTRAINT uq_hive_accounts_reversible UNIQUE( name, fork_id )
;

CREATE UNLOGGED TABLE IF NOT EXISTS hive.account_operations_reversible(
    LIKE hive.account_operations
    INCLUDING ALL
    EXCLUDING CONSTRAINTS -- because of unique(account_id, account_op_seq_no) and (account_id, operation_id)
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
)
;
SELECT pg_catalog.pg_extension_config_dump('account_operations_reversible', '');
ALTER TABLE hive.account_operations_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT fk_1_hive_account_operations_reversible FOREIGN KEY ( operation_id, fork_id ) REFERENCES hive.operations_reversible( id, fork_id ),
    ADD CONSTRAINT pk_hive_account_operations_reversible PRIMARY KEY( account_id, account_op_seq_no, fork_id )
;

CREATE UNLOGGED TABLE IF NOT EXISTS hive.applied_hardforks_reversible(
    LIKE hive.applied_hardforks
    INCLUDING ALL
    EXCLUDING CONSTRAINTS
    EXCLUDING STATISTICS
    EXCLUDING INDEXES
    EXCLUDING IDENTITY
);
SELECT pg_catalog.pg_extension_config_dump('applied_hardforks_reversible', '');
ALTER TABLE hive.applied_hardforks_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_hive_applied_hardforks_reversible PRIMARY KEY( hardfork_num, fork_id ),
    ADD CONSTRAINT fk_1_hive_applied_hardforks_reversible FOREIGN KEY ( block_num, fork_id ) REFERENCES hive.blocks_reversible( num, fork_id )

;

CREATE INDEX IF NOT EXISTS hive_applied_hardforks_reversible_block_num_idx ON hive.applied_hardforks_reversible( block_num );
CREATE INDEX IF NOT EXISTS hive_applied_hardforks_reversible_fork_id_idx ON hive.applied_hardforks_reversible( fork_id );
CREATE INDEX IF NOT EXISTS hive_transactions_reversible_block_num_trx_in_block_fork_id_idx ON hive.transactions_reversible( block_num, trx_in_block, fork_id );
CREATE INDEX IF NOT EXISTS hive_operations_reversible_block_num_type_id_trx_in_block_fork_id_idx ON hive.operations_reversible( block_num, op_type_id, trx_in_block, fork_id );
CREATE INDEX IF NOT EXISTS hive_operations_reversible_block_num_id_idx ON hive.operations_reversible USING btree(block_num, id, fork_id);
CREATE INDEX IF NOT EXISTS hive_account_operations_reversible_operation_id_idx ON hive.account_operations_reversible(operation_id, fork_id);
CREATE INDEX IF NOT EXISTS hive_account_operations_reversible_type_account_id_op_seq_idx ON hive.account_operations_reversible( op_type_id, account_id, account_op_seq_no DESC ) INCLUDE( operation_id, block_num );
