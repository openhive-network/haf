CREATE DOMAIN hive.vest_amount AS NUMERIC NOT NULL;
CREATE DOMAIN hive.hive_amount AS NUMERIC NOT NULL;
CREATE DOMAIN hive.hbd_amount AS NUMERIC NOT NULL;
--- Interest rate (in BPS - basis points)
CREATE DOMAIN hive.interest_rate AS INT4 NOT NULL;

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
SELECT pg_catalog.pg_extension_config_dump('hive.blocks', '');

CREATE TABLE IF NOT EXISTS hive.irreversible_data (
      id integer,
      consistent_block integer,
      is_dirty bool NOT NULL,
      CONSTRAINT pk_irreversible_data PRIMARY KEY ( id )
);

-- We use ADD CONSTRAINT with ALTER TABLE followed by NOT VALID because the NOT VALID option isn't documented
-- or supported within CREATE TABLE, and thus, seems not to work there.
-- This applies to the following tables as well.
ALTER TABLE hive.irreversible_data ADD CONSTRAINT fk_1_hive_irreversible_data FOREIGN KEY (consistent_block) REFERENCES hive.blocks (num) NOT VALID;
SELECT pg_catalog.pg_extension_config_dump('hive.irreversible_data', '');

CREATE TABLE IF NOT EXISTS hive.transactions (
    block_num integer NOT NULL,
    trx_in_block smallint NOT NULL,
    trx_hash bytea NOT NULL,
    ref_block_num integer NOT NULL,
    ref_block_prefix bigint NOT NULL,
    expiration timestamp without time zone NOT NULL,
    signature bytea DEFAULT NULL,
    CONSTRAINT pk_hive_transactions PRIMARY KEY ( trx_hash )
);
ALTER TABLE hive.transactions ADD CONSTRAINT fk_1_hive_transactions FOREIGN KEY (block_num) REFERENCES hive.blocks (num) NOT VALID;
SELECT pg_catalog.pg_extension_config_dump('hive.transactions', '');

CREATE TABLE IF NOT EXISTS hive.transactions_multisig (
    trx_hash bytea NOT NULL,
    signature bytea NOT NULL,
    CONSTRAINT pk_hive_transactions_multisig PRIMARY KEY ( trx_hash, signature )
);
ALTER TABLE transactions_multisig ADD CONSTRAINT fk_1_hive_transactions_multisig FOREIGN KEY (trx_hash) REFERENCES hive.transactions (trx_hash) NOT VALID;
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
    -- id is encoded || 32b blocknum | 24b seq | 8b operation type ||
    id bigint not null,
    trx_in_block smallint NOT NULL,
    op_pos integer NOT NULL,
    -- timestamp: Specific to operation kind.  It may be set for block time -3s (current hived head_block_time)
    -- or for **next**  block time (when hived node finished evaluation of current block).
    -- This behavior depends on hived implementation, and **this logic should not be** repeated HAF-client app side. Specifically:
    -- - regular user operations put into transactions got head_block_time: -3s ( time of block predecessing currently applied block )
    -- - fork and schedule operations got head_block_time: -3s ( time of block predecessing currently applied block )
    -- - system triggered virtual operations usualy are created after applaying current block and got time equals its time
    --   (after hived not changed head_block to another one)
    timestamp TIMESTAMP NOT NULL,
    body_binary hive.operation  DEFAULT NULL,
    CONSTRAINT pk_hive_operations PRIMARY KEY ( id )
);

CREATE OR REPLACE FUNCTION hive.operation_id_to_block_num_wrapper( _id BIGINT )
    RETURNS INTEGER
    IMMUTABLE
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    RETURN hive.operation_id_to_block_num(_id);
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.operation_id_to_type_id_wrapper( _id BIGINT )
    RETURNS INTEGER
    IMMUTABLE
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    RETURN hive.operation_id_to_type_id(_id);
END;
$BODY$;


CREATE OR REPLACE FUNCTION hive.operation_id_to_pos_wrapper( _id BIGINT )
    RETURNS INTEGER
    IMMUTABLE
    LANGUAGE plpgsql
AS
$BODY$
BEGIN
    RETURN hive.operation_id_to_pos(_id);
END;
$BODY$;

SELECT pg_catalog.pg_extension_config_dump('hive.operations', '');

CREATE TABLE IF NOT EXISTS hive.applied_hardforks (
    hardfork_num smallint NOT NULL,
    block_num integer NOT NULL,
    hardfork_vop_id bigint NOT NULL,
    CONSTRAINT pk_hive_applied_hardforks PRIMARY KEY (hardfork_num)
);
ALTER TABLE hive.applied_hardforks ADD CONSTRAINT fk_1_hive_applied_hardforks FOREIGN KEY (hardfork_vop_id) REFERENCES hive.operations(id) NOT VALID;
ALTER TABLE hive.applied_hardforks ADD CONSTRAINT fk_2_hive_applied_hardforks FOREIGN KEY (block_num) REFERENCES hive.blocks(num) NOT VALID;
SELECT pg_catalog.pg_extension_config_dump('hive.applied_hardforks', '');

CREATE TABLE IF NOT EXISTS hive.accounts (
      id INTEGER NOT NULL
    , name VARCHAR(16) NOT NULL
    , block_num INTEGER
    , CONSTRAINT pk_hive_accounts_id PRIMARY KEY( id )
    , CONSTRAINT uq_hive_accounst_name UNIQUE ( name )
    
);
ALTER TABLE hive.accounts ADD CONSTRAINT fk_1_hive_accounts FOREIGN KEY (block_num) REFERENCES hive.blocks (num) MATCH FULL NOT VALID;
SELECT pg_catalog.pg_extension_config_dump('hive.accounts', '');

CREATE TABLE IF NOT EXISTS hive.account_operations
(
      account_id INTEGER NOT NULL --- Identifier of account involved in given operation.
    , account_op_seq_no INTEGER NOT NULL --- Operation sequence number specific to given account.
    , operation_id BIGINT NOT NULL --- Id of operation held in hive_opreations table.
    , CONSTRAINT hive_account_operations_uq1 UNIQUE( account_id, account_op_seq_no ) --try account,op_type,account_op_seq_no?
    -- Hopefully not needed anymore, let's find out
    --, CONSTRAINT hive_account_operations_uq2 UNIQUE ( account,operation_id )
);
ALTER TABLE hive.account_operations ADD CONSTRAINT hive_account_operations_fk_1 FOREIGN KEY (account_id) REFERENCES hive.accounts(id) NOT VALID;
ALTER TABLE hive.account_operations ADD CONSTRAINT hive_account_operations_fk_2 FOREIGN KEY (operation_id) REFERENCES hive.operations(id) NOT VALID;
SELECT pg_catalog.pg_extension_config_dump('hive.account_operations', '');


CREATE INDEX IF NOT EXISTS hive_applied_hardforks_block_num_idx ON hive.applied_hardforks ( block_num );

CREATE INDEX IF NOT EXISTS hive_transactions_block_num_trx_in_block_idx ON hive.transactions ( block_num, trx_in_block );

CREATE INDEX IF NOT EXISTS hive_operations_block_num_id_idx ON hive.operations USING btree( hive.operation_id_to_block_num_wrapper(id), id);
CREATE INDEX IF NOT EXISTS hive_operations_block_num_trx_in_block_idx ON hive.operations USING btree (hive.operation_id_to_block_num_wrapper(id) ASC NULLS LAST, trx_in_block ASC NULLS LAST, hive.operation_id_to_type_id_wrapper(id));
CREATE INDEX IF NOT EXISTS hive_operations_op_type_id_block_num ON hive.operations (hive.operation_id_to_type_id_wrapper(id), hive.operation_id_to_block_num_wrapper(id));

--Clustering to speedup get_account_history queries (returns ordered set of operations for a specific account)
--Clustering takes 2 hours on a fast system with 4 maintenance works
--Clustering is actually done by hived, and the line below could technically be removed.
--Eventually we need functions on haf side to perform the clustering and make it part
--of adding indexes to the account_operations table to allow for more parallelism.
CLUSTER hive.account_operations using hive_account_operations_uq1;

--This index is probably only needed for block_explorer queries right now, but maybe useful for other apps,
--so decided to add here rather than as part of hafbe as it isn't huge.
CREATE INDEX IF NOT EXISTS hive_account_operations_account_id_op_type_id_idx ON hive.account_operations( account_id, hive.operation_id_to_type_id_wrapper(operation_id ) );

CREATE INDEX IF NOT EXISTS hive_accounts_block_num_idx ON hive.accounts USING btree (block_num);

CREATE INDEX IF NOT EXISTS hive_blocks_producer_account_id_idx ON hive.blocks (producer_account_id);
CREATE INDEX IF NOT EXISTS hive_blocks_created_at_idx ON hive.blocks USING btree ( created_at );

ALTER TABLE hive.blocks ADD CONSTRAINT fk_1_hive_blocks FOREIGN KEY (producer_account_id) REFERENCES hive.accounts (id) NOT VALID DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE IF NOT EXISTS hive.write_ahead_log_state (id SMALLINT NOT NULL UNIQUE CHECK (id = 1), last_sequence_number_committed INTEGER);
COMMENT ON TABLE hive.write_ahead_log_state IS 'Tracks the sequence numbers in hived''s write-ahead log';
COMMENT ON COLUMN hive.write_ahead_log_state.id IS 'an id column.  this table will never have more than one row, and its id will be 1.  an empty table is semantically equivalent to a table where the last_sequence_number_committed is NULL';
COMMENT ON COLUMN hive.write_ahead_log_state.last_sequence_number_committed IS 'The sequence number of the last commited transaction, or NULL if we''re operating in a mode that doesn''t track sequence numbers.  Will always be non-negative';

SELECT pg_catalog.pg_extension_config_dump('hive.write_ahead_log_state', '');

