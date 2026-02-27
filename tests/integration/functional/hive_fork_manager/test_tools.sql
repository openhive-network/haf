-- HAF Test Tools: Common functions for test data setup
-- This file provides reusable functions to reduce code duplication across functional tests
-- All functions are in the 'test' schema to avoid conflicts with production code
--
-- NOTE: This version works with unified tables using block_id encoding.
-- There are no separate *_reversible tables. All data goes into unified tables
-- with block_id = make_block_id(block_num, fork_id).

-- Create test schema if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'test') THEN
        CREATE SCHEMA test;
    END IF;
END
$$;

-- ============================================================================
-- SECTION 1: BASIC INFRASTRUCTURE SETUP
-- ============================================================================

-- Setup standard operation types
CREATE OR REPLACE FUNCTION test.create_operation_types()
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE)
         , (1, 'OP 1', FALSE)
         , (2, 'OP 2', FALSE)
         , (3, 'OP 3', TRUE);
END;
$BODY$;

COMMENT ON FUNCTION test.create_operation_types() IS
'Creates standard test operation types (OP 0-3) in hafd.operation_types table';


-- Setup standard fork structure
CREATE OR REPLACE FUNCTION test.create_forks(
    fork_ids INT[] DEFAULT ARRAY[2, 3],
    fork_blocks INT[] DEFAULT ARRAY[6, 7],
    fork_time TIMESTAMP DEFAULT '2020-06-22 19:10:25-07'::timestamp
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    i INT;
BEGIN
    FOR i IN 1..array_length(fork_ids, 1) LOOP
        INSERT INTO hafd.fork(id, block_num, time_of_fork)
        VALUES (fork_ids[i], fork_blocks[i], fork_time);
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_forks(INT[], INT[], TIMESTAMP) IS
'Creates fork entries in hafd.fork table. Default creates forks 2 and 3 at blocks 6 and 7';


-- Setup standard test accounts (irreversible, fork_id=0)
CREATE OR REPLACE FUNCTION test.create_accounts(
    start_id INT DEFAULT 5,
    account_names TEXT[] DEFAULT ARRAY['initminer', 'alice', 'bob'],
    block_num INT DEFAULT 1
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    i INT;
    __block_id hafd.block_id;
BEGIN
    __block_id := hafd.make_block_id(block_num, 0);  -- fork_id=0 for irreversible
    FOR i IN 1..array_length(account_names, 1) LOOP
        INSERT INTO hafd.accounts(id, name, block_id)
        VALUES (start_id + i - 1, account_names[i], __block_id);
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_accounts(INT, TEXT[], INT) IS
'Creates test accounts in hafd.accounts table. Default creates initminer, alice, and bob starting at ID 5';


-- ============================================================================
-- SECTION 2: BLOCK CREATION FUNCTIONS
-- ============================================================================

-- Create a range of irreversible blocks (fork_id=0)
CREATE OR REPLACE FUNCTION test.create_blocks(
    start_block INT,
    end_block INT,
    producer_id INT DEFAULT 5,
    base_time TIMESTAMP DEFAULT '2016-06-22 19:10:21-07'::timestamp
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    block_num INT;
    hash_suffix TEXT;
    prev_suffix TEXT;
    __block_id hafd.block_id;
BEGIN
    FOR block_num IN start_block..end_block LOOP
        hash_suffix := lpad(to_hex(block_num * 16), 2, '0');
        prev_suffix := lpad(to_hex(block_num * 16), 2, '0');
        __block_id := hafd.make_block_id(block_num, 0);  -- fork_id=0 for irreversible

        INSERT INTO hafd.blocks (block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger)
        VALUES (
            __block_id,
            decode('BADD' || hash_suffix, 'hex'),
            decode('CAFE' || prev_suffix, 'hex'),
            base_time + ((block_num - 1) || ' seconds')::interval,
            producer_id,
            '\x4007'::bytea,
            '[]'::jsonb,
            '\x2157'::bytea,
            'STM65w',
            1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_blocks(INT, INT, INT, TIMESTAMP) IS
'Creates a range of irreversible blocks (fork_id=0) in hafd.blocks table with auto-generated hashes';


-- Create a range of reversible blocks (with specified fork_id)
CREATE OR REPLACE FUNCTION test.create_blocks_reversible(
    start_block INT,
    end_block INT,
    fork_id INT,
    producer_id INT DEFAULT 5,
    base_time TIMESTAMP DEFAULT '2016-06-22 19:10:25-07'::timestamp
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    __block_num INT;
    hash_suffix TEXT;
    prev_suffix TEXT;
    __block_id hafd.block_id;
BEGIN
    FOR __block_num IN start_block..end_block LOOP
        -- Add fork_id to hash to create unique hashes per fork
        hash_suffix := lpad(to_hex(__block_num * 16 + fork_id), 2, '0');
        prev_suffix := lpad(to_hex(__block_num * 16 + fork_id), 2, '0');
        __block_id := hafd.make_block_id(__block_num, fork_id);

        INSERT INTO hafd.blocks (block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger)
        VALUES (
            __block_id,
            decode('BADD' || hash_suffix, 'hex'),
            decode('CAFE' || prev_suffix, 'hex'),
            base_time + ((__block_num - 1) || ' seconds')::interval,
            producer_id,
            '\x4007'::bytea,
            '[]'::jsonb,
            '\x2157'::bytea,
            'STM65w',
            1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000
        );

        -- Track conflict if this block_num already has another version (matches push_block behavior)
        INSERT INTO hafd.block_conflicts (block_num)
        SELECT __block_num
        WHERE EXISTS (
            SELECT 1 FROM hafd.blocks hb
            WHERE hb.block_num = __block_num
              AND hb.block_id != __block_id
        )
        ON CONFLICT DO NOTHING;
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_blocks_reversible(INT, INT, INT, INT, TIMESTAMP) IS
'Creates a range of reversible blocks in hafd.blocks table with specified fork_id.
Also populates hafd.block_conflicts when a block_num already has another version,
matching hive.push_block() production behavior.';


-- Populate block_conflicts from existing blocks data
-- Call this after inserting blocks with overlapping block_nums across forks
-- when using raw INSERT (not create_blocks_reversible which handles this automatically)
CREATE OR REPLACE FUNCTION test.populate_block_conflicts()
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    INSERT INTO hafd.block_conflicts (block_num)
    SELECT hafd.block_id_to_num(block_id)
    FROM hafd.blocks
    GROUP BY hafd.block_id_to_num(block_id)
    HAVING COUNT(*) > 1
    ON CONFLICT DO NOTHING;
END;
$BODY$;

COMMENT ON FUNCTION test.populate_block_conflicts() IS
'Derives block_conflicts from existing blocks data. Call after raw INSERT
into hafd.blocks when blocks have multiple fork versions.';


-- ============================================================================
-- SECTION 3: TRANSACTION CREATION FUNCTIONS
-- ============================================================================

-- Create irreversible transactions (fork_id=0)
CREATE OR REPLACE FUNCTION test.create_transactions(
    start_block INT,
    end_block INT,
    trx_in_block SMALLINT DEFAULT 0,
    base_time TIMESTAMP DEFAULT '2016-06-22 19:10:21-07'::timestamp
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    block_num INT;
    hash_suffix TEXT;
    __block_id hafd.block_id;
BEGIN
    FOR block_num IN start_block..end_block LOOP
        hash_suffix := lpad(to_hex(block_num * 16), 2, '0');
        __block_id := hafd.make_block_id(block_num, 0);  -- fork_id=0 for irreversible

        INSERT INTO hafd.transactions
        VALUES (
            __block_id,
            trx_in_block,
            decode('DEED' || hash_suffix, 'hex'),
            101,
            100,
            base_time + ((block_num - 1) || ' seconds')::interval,
            '\xBEEF'::bytea
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_transactions(INT, INT, SMALLINT, TIMESTAMP) IS
'Creates irreversible transactions (fork_id=0) in hafd.transactions table';


-- Create reversible transactions (with specified fork_id)
CREATE OR REPLACE FUNCTION test.create_transactions_reversible(
    start_block INT,
    end_block INT,
    fork_id INT,
    trx_in_block SMALLINT DEFAULT 0,
    base_time TIMESTAMP DEFAULT '2016-06-22 19:10:24-07'::timestamp
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    block_num INT;
    hash_suffix TEXT;
    __block_id hafd.block_id;
BEGIN
    FOR block_num IN start_block..end_block LOOP
        hash_suffix := lpad(to_hex(block_num * 16 + fork_id), 2, '0');
        __block_id := hafd.make_block_id(block_num, fork_id);

        INSERT INTO hafd.transactions
        VALUES (
            __block_id,
            trx_in_block,
            decode('DEED' || hash_suffix, 'hex'),
            101,
            100,
            base_time + ((block_num - 1) || ' seconds')::interval,
            '\xBEEF'::bytea
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_transactions_reversible(INT, INT, INT, SMALLINT, TIMESTAMP) IS
'Creates reversible transactions in hafd.transactions table with specified fork_id';


-- Create transaction signatures (multisig) - irreversible (fork_id=0)
CREATE OR REPLACE FUNCTION test.create_transaction_signatures(
    start_block INT,
    end_block INT
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    block_num INT;
    sig_suffix TEXT;
    __block_id hafd.block_id;
BEGIN
    FOR block_num IN start_block..end_block LOOP
        sig_suffix := lpad(to_hex(block_num * 16), 2, '0');
        __block_id := hafd.make_block_id(block_num, 0);  -- fork_id=0

        INSERT INTO hafd.transactions_multisig(trx_hash, signature, block_id)
        VALUES (
            decode('DEED' || sig_suffix, 'hex'),
            decode('BAAD' || sig_suffix, 'hex'),
            __block_id
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_transaction_signatures(INT, INT) IS
'Creates transaction signatures in hafd.transactions_multisig table (fork_id=0)';


-- Create transaction signatures (multisig) - reversible
CREATE OR REPLACE FUNCTION test.create_transaction_signatures_reversible(
    start_block INT,
    end_block INT,
    fork_id INT
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    block_num INT;
    sig_suffix TEXT;
    __block_id hafd.block_id;
BEGIN
    FOR block_num IN start_block..end_block LOOP
        sig_suffix := lpad(to_hex(block_num * 16 + fork_id), 2, '0');
        __block_id := hafd.make_block_id(block_num, fork_id);

        INSERT INTO hafd.transactions_multisig(trx_hash, signature, block_id)
        VALUES (
            decode('DEED' || sig_suffix, 'hex'),
            decode('BEEF' || sig_suffix, 'hex'),
            __block_id
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_transaction_signatures_reversible(INT, INT, INT) IS
'Creates reversible transaction signatures in hafd.transactions_multisig table';


-- ============================================================================
-- SECTION 4: OPERATION CREATION FUNCTIONS
-- ============================================================================

-- Create irreversible operations (fork_id=0)
CREATE OR REPLACE FUNCTION test.create_operations(
    start_block INT,
    end_block INT,
    trx_in_block INT DEFAULT 1,
    op_pos INT DEFAULT 0
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    block_num INT;
    message TEXT;
    __block_id hafd.block_id;
BEGIN
    FOR block_num IN start_block..end_block LOOP
        message := 'OPERATION BLOCK ' || block_num::TEXT;
        __block_id := hafd.make_block_id(block_num, 0);  -- fork_id=0

        INSERT INTO hafd.operations(block_id, trx_in_block, op_type_id, op_pos, body_binary, id)
        VALUES (
            __block_id,
            trx_in_block - 1,
            0,  -- op_type_id: default test type
            op_pos,
            ('{"type":"system_warning_operation","value":{"message":"' || message || '"}}')::jsonb::hafd.operation,
            hafd.operation_id(block_num, op_pos)  -- id encoding: (block_num << 32) | pos_in_block
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_operations(INT, INT, INT, INT) IS
'Creates irreversible operations (fork_id=0) in hafd.operations table';


-- Create reversible operations
CREATE OR REPLACE FUNCTION test.create_operations_reversible(
    start_block INT,
    end_block INT,
    fork_id INT,
    trx_in_block INT DEFAULT 1,
    op_pos INT DEFAULT 0
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    block_num INT;
    message TEXT;
    __block_id hafd.block_id;
BEGIN
    FOR block_num IN start_block..end_block LOOP
        message := 'OPERATION BLOCK ' || block_num::TEXT || ' FORK ' || fork_id::TEXT;
        __block_id := hafd.make_block_id(block_num, fork_id);

        INSERT INTO hafd.operations(block_id, trx_in_block, op_type_id, op_pos, body_binary, id)
        VALUES (
            __block_id,
            trx_in_block - 1,
            0,  -- op_type_id: default test type
            op_pos,
            ('{"type":"system_warning_operation","value":{"message":"' || message || '"}}')::jsonb::hafd.operation,
            hafd.operation_id(block_num, op_pos)  -- id encoding: (block_num << 32) | pos_in_block
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_operations_reversible(INT, INT, INT, INT, INT) IS
'Creates reversible operations in hafd.operations table with specified fork_id';


-- ============================================================================
-- SECTION 5: ACCOUNT OPERATIONS FUNCTIONS
-- ============================================================================

-- Create account operations (irreversible, fork_id=0)
CREATE OR REPLACE FUNCTION test.create_account_operations(
    start_block INT,
    end_block INT,
    account_id INT,
    transacting_account_id INT DEFAULT NULL,
    trx_in_block INT DEFAULT 1,
    op_pos INT DEFAULT 0
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    block_num INT;
    seq_no INT := 1;
    trans_acc_id INT;
    __block_id hafd.block_id;
BEGIN
    trans_acc_id := COALESCE(transacting_account_id, account_id);

    FOR block_num IN start_block..end_block LOOP
        __block_id := hafd.make_block_id(block_num, 0);  -- fork_id=0

        INSERT INTO hafd.account_operations(block_id, operation_id, account_id, transacting_account_id, account_op_seq_no, op_type_id)
        VALUES (
            __block_id,
            hafd.operation_id(hafd.block_id_to_num(__block_id), op_pos),  -- operation_id: (block_num << 32) | pos_in_block
            account_id,
            trans_acc_id,
            seq_no,
            0  -- op_type_id: default test type
        );
        seq_no := seq_no + 1;
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_account_operations(INT, INT, INT, INT, INT, INT) IS
'Creates account operations (fork_id=0) in hafd.account_operations table for a specific account';


-- Create account operations (reversible)
CREATE OR REPLACE FUNCTION test.create_account_operations_reversible(
    start_block INT,
    end_block INT,
    account_id INT,
    fork_id INT,
    transacting_account_id INT DEFAULT NULL,
    trx_in_block INT DEFAULT 1,
    op_pos INT DEFAULT 0
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    block_num INT;
    seq_no INT := 1;
    trans_acc_id INT;
    __block_id hafd.block_id;
BEGIN
    trans_acc_id := COALESCE(transacting_account_id, account_id);

    FOR block_num IN start_block..end_block LOOP
        __block_id := hafd.make_block_id(block_num, fork_id);

        INSERT INTO hafd.account_operations(block_id, operation_id, account_id, transacting_account_id, account_op_seq_no, op_type_id)
        VALUES (
            __block_id,
            hafd.operation_id(hafd.block_id_to_num(__block_id), op_pos),  -- operation_id: (block_num << 32) | pos_in_block
            account_id,
            trans_acc_id,
            seq_no,
            0  -- op_type_id: default test type
        );
        seq_no := seq_no + 1;
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_account_operations_reversible(INT, INT, INT, INT, INT, INT, INT) IS
'Creates reversible account operations with specified fork_id for a specific account';


-- Create accounts (reversible)
CREATE OR REPLACE FUNCTION test.create_accounts_reversible(
    start_id INT,
    end_id INT,
    block_num INT,
    fork_id INT,
    name_prefix TEXT DEFAULT 'account'
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    acc_id INT;
    __block_id hafd.block_id;
BEGIN
    __block_id := hafd.make_block_id(block_num, fork_id);

    FOR acc_id IN start_id..end_id LOOP
        INSERT INTO hafd.accounts(id, name, block_id)
        VALUES (
            acc_id,
            name_prefix || acc_id::TEXT,
            __block_id
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_accounts_reversible(INT, INT, INT, INT, TEXT) IS
'Creates reversible accounts in hafd.accounts table with specified fork_id';


-- ============================================================================
-- SECTION 6: APPLIED HARDFORKS FUNCTIONS
-- ============================================================================

-- Create applied hardforks (irreversible, fork_id=0)
CREATE OR REPLACE FUNCTION test.create_applied_hardforks(
    start_block INT,
    end_block INT,
    trx_in_block INT DEFAULT 1,
    op_pos INT DEFAULT 0
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    block_num INT;
    hf_num INT;
    __block_id hafd.block_id;
BEGIN
    hf_num := start_block;
    FOR block_num IN start_block..end_block LOOP
        __block_id := hafd.make_block_id(block_num, 0);  -- fork_id=0

        INSERT INTO hafd.applied_hardforks(hardfork_num, block_id, hardfork_vop_id)
        VALUES (
            hf_num,
            __block_id,
            trx_in_block  -- hardfork_vop_id
        );
        hf_num := hf_num + 1;
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_applied_hardforks(INT, INT, INT, INT) IS
'Creates applied hardforks (fork_id=0) in hafd.applied_hardforks table';


-- Create applied hardforks (reversible)
CREATE OR REPLACE FUNCTION test.create_applied_hardforks_reversible(
    start_block INT,
    end_block INT,
    fork_id INT,
    trx_in_block INT DEFAULT 1,
    op_pos INT DEFAULT 0
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    block_num INT;
    hf_num INT;
    __block_id hafd.block_id;
BEGIN
    hf_num := start_block;
    FOR block_num IN start_block..end_block LOOP
        __block_id := hafd.make_block_id(block_num, fork_id);

        INSERT INTO hafd.applied_hardforks(hardfork_num, block_id, hardfork_vop_id)
        VALUES (
            hf_num,
            __block_id,
            trx_in_block  -- hardfork_vop_id
        );
        hf_num := hf_num + 1;
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_applied_hardforks_reversible(INT, INT, INT, INT, INT) IS
'Creates reversible applied hardforks with specified fork_id';


-- ============================================================================
-- SECTION 7: HIGH-LEVEL COMPOSITE FUNCTIONS
-- ============================================================================

-- Create a complete irreversible blockchain up to a block
CREATE OR REPLACE FUNCTION test.create_irreversible_data(
    end_block INT,
    include_accounts BOOLEAN DEFAULT TRUE,
    include_transactions BOOLEAN DEFAULT TRUE,
    include_operations BOOLEAN DEFAULT TRUE,
    include_signatures BOOLEAN DEFAULT FALSE,
    include_hardforks BOOLEAN DEFAULT FALSE,
    include_account_operations BOOLEAN DEFAULT FALSE
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    -- Always create blocks
    PERFORM test.create_blocks(1, end_block);

    IF include_accounts THEN
        PERFORM test.create_accounts();
    END IF;

    IF include_transactions THEN
        PERFORM test.create_transactions(1, end_block);
    END IF;

    IF include_operations THEN
        PERFORM test.create_operations(1, end_block);
    END IF;

    IF include_signatures THEN
        PERFORM test.create_transaction_signatures(1, end_block);
    END IF;

    IF include_hardforks THEN
        PERFORM test.create_applied_hardforks(1, end_block);
    END IF;

    IF include_account_operations AND include_accounts THEN
        -- Create account operations for account id 5 (initminer)
        PERFORM test.create_account_operations(1, end_block, 5);
    END IF;
END;
$BODY$;

COMMENT ON FUNCTION test.create_irreversible_data(INT, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN) IS
'Creates a complete set of irreversible blockchain data (fork_id=0) up to specified block. Flags control which data types to include.';


-- Create reversible data for a specific fork
CREATE OR REPLACE FUNCTION test.create_reversible_data_for_fork(
    start_block INT,
    end_block INT,
    fork_id INT,
    include_accounts BOOLEAN DEFAULT FALSE,
    include_transactions BOOLEAN DEFAULT TRUE,
    include_operations BOOLEAN DEFAULT TRUE,
    include_signatures BOOLEAN DEFAULT FALSE,
    include_hardforks BOOLEAN DEFAULT FALSE,
    include_account_operations BOOLEAN DEFAULT FALSE
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    -- Always create blocks
    PERFORM test.create_blocks_reversible(start_block, end_block, fork_id);

    IF include_accounts THEN
        PERFORM test.create_accounts_reversible(5, 7, start_block, fork_id, 'account');
    END IF;

    IF include_transactions THEN
        PERFORM test.create_transactions_reversible(start_block, end_block, fork_id);
    END IF;

    IF include_operations THEN
        PERFORM test.create_operations_reversible(start_block, end_block, fork_id);
    END IF;

    IF include_signatures THEN
        PERFORM test.create_transaction_signatures_reversible(start_block, end_block, fork_id);
    END IF;

    IF include_hardforks THEN
        PERFORM test.create_applied_hardforks_reversible(start_block, end_block, fork_id);
    END IF;

    IF include_account_operations AND include_accounts THEN
        -- Create account operations for account id 5
        PERFORM test.create_account_operations_reversible(start_block, end_block, 5, fork_id);
    END IF;
END;
$BODY$;

COMMENT ON FUNCTION test.create_reversible_data_for_fork(INT, INT, INT, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN) IS
'Creates a complete set of reversible blockchain data for a specific fork. Flags control which data types to include.';


-- Create a complete test blockchain scenario with forks
CREATE OR REPLACE FUNCTION test.create_test_blockchain(
    irreversible_blocks INT DEFAULT 5,
    reversible_blocks_per_fork INT DEFAULT 3,
    fork_count INT DEFAULT 2,
    include_all_data BOOLEAN DEFAULT TRUE
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    fork_id INT;
    fork_ids INT[];
    fork_blocks INT[];
BEGIN
    -- Setup infrastructure
    PERFORM test.create_operation_types();
    PERFORM test.create_accounts();

    -- Create irreversible data
    PERFORM test.create_irreversible_data(
        irreversible_blocks,
        include_accounts => FALSE, -- already created
        include_transactions => include_all_data,
        include_operations => include_all_data,
        include_signatures => include_all_data,
        include_hardforks => include_all_data,
        include_account_operations => include_all_data
    );

    -- Prepare fork configuration
    fork_ids := ARRAY(SELECT generate_series(2, fork_count + 1));
    fork_blocks := ARRAY(SELECT generate_series(irreversible_blocks + 1, irreversible_blocks + fork_count));

    -- Create forks
    PERFORM test.create_forks(fork_ids, fork_blocks);

    -- Create reversible data for each fork
    FOR fork_id IN 1..(fork_count + 1) LOOP
        PERFORM test.create_reversible_data_for_fork(
            irreversible_blocks + 1,
            irreversible_blocks + reversible_blocks_per_fork,
            fork_id,
            include_accounts => include_all_data,
            include_transactions => include_all_data,
            include_operations => include_all_data,
            include_signatures => include_all_data,
            include_hardforks => include_all_data,
            include_account_operations => include_all_data
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_test_blockchain(INT, INT, INT, BOOLEAN) IS
'Creates a complete test blockchain with irreversible blocks, multiple forks, and all associated data types.
Parameters:
- irreversible_blocks: Number of irreversible blocks to create
- reversible_blocks_per_fork: Number of reversible blocks per fork
- fork_count: Number of forks (actual forks will be fork_count + 1 including main fork)
- include_all_data: If true, creates all related data (transactions, operations, accounts, etc.)';


-- ============================================================================
-- SECTION 8: SIMPLE SCENARIO BUILDERS
-- ============================================================================

-- Simple scenario: Basic blockchain without forks
CREATE OR REPLACE FUNCTION test.setup_simple_blockchain(
    num_blocks INT DEFAULT 8
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    PERFORM test.create_operation_types();
    -- Create blocks before accounts due to FK constraint
    PERFORM test.create_blocks(1, num_blocks);
    PERFORM test.create_accounts();
    PERFORM test.create_transactions(1, num_blocks);
    PERFORM test.create_operations(1, num_blocks);
END;
$BODY$;

COMMENT ON FUNCTION test.setup_simple_blockchain(INT) IS
'Sets up a simple blockchain without forks - includes operation types, accounts, blocks, transactions, and operations';


-- Simple scenario: Blockchain with 2 forks (standard test pattern)
CREATE OR REPLACE FUNCTION test.setup_standard_fork_scenario()
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    PERFORM test.create_operation_types();
    PERFORM test.create_forks(); -- Default: forks 2 and 3 at blocks 6 and 7

    -- Irreversible data (blocks 1-5) - must be before accounts due to FK
    PERFORM test.create_blocks(1, 5);

    -- Create accounts after blocks (FK constraint)
    PERFORM test.create_accounts();
    PERFORM test.create_transactions(1, 5);
    PERFORM test.create_operations(1, 5);

    -- Reversible data for fork 1 (main)
    PERFORM test.create_blocks_reversible(4, hafd.make_block_id(10, 0), 1);
    PERFORM test.create_transactions_reversible(4, hafd.make_block_id(10, 0), 1);
    PERFORM test.create_operations_reversible(4, hafd.make_block_id(10, 0), 1);

    -- Reversible data for fork 2
    PERFORM test.create_blocks_reversible(7, hafd.make_block_id(10, 0), 2);
    PERFORM test.create_transactions_reversible(7, hafd.make_block_id(10, 0), 2);
    PERFORM test.create_operations_reversible(7, hafd.make_block_id(10, 0), 2);

    -- Reversible data for fork 3
    PERFORM test.create_blocks_reversible(8, hafd.make_block_id(10, 0), 3);
    PERFORM test.create_transactions_reversible(8, hafd.make_block_id(10, 0), 3);
    PERFORM test.create_operations_reversible(8, hafd.make_block_id(10, 0), 3);
END;
$BODY$;

COMMENT ON FUNCTION test.setup_standard_fork_scenario() IS
'Sets up the standard fork test scenario seen in most tests: 5 irreversible blocks, 3 forks with reversible data';


-- ============================================================================
-- SECTION 9: MOCK AND UTILITY FUNCTIONS
-- ============================================================================

-- Install mock for hive head block estimation (for application_loop tests)
CREATE OR REPLACE FUNCTION test.install_mock_hive_get_estimated_hive_head_block()
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    -- Create a table to store mock head block value
    CREATE TABLE IF NOT EXISTS test.mock_head_block (
        head_block_num INT
    );

    -- Grant permissions to application users
    GRANT SELECT, UPDATE ON test.mock_head_block TO PUBLIC;

    -- Initialize with default value
    TRUNCATE test.mock_head_block;
    INSERT INTO test.mock_head_block VALUES (50);

    -- Create mock function
    CREATE OR REPLACE FUNCTION hive.get_estimated_hive_head_block()
    RETURNS INT
    LANGUAGE 'plpgsql' AS
    $MOCK$
    BEGIN
        RETURN (SELECT head_block_num FROM test.mock_head_block LIMIT 1);
    END;
    $MOCK$;
END;
$BODY$;

COMMENT ON FUNCTION test.install_mock_hive_get_estimated_hive_head_block() IS
'Installs a mock version of hive.get_estimated_hive_head_block() for testing. Use test.set_head_block_num() to change the value.';


-- Set mock head block number
CREATE OR REPLACE FUNCTION test.set_head_block_num(block_num INT)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    UPDATE test.mock_head_block SET head_block_num = block_num;
END;
$BODY$;

COMMENT ON FUNCTION test.set_head_block_num(INT) IS
'Sets the mock head block number used by test.install_mock_hive_get_estimated_hive_head_block()';


-- ============================================================================
-- SECTION 10: HASH GENERATION FUNCTIONS (for assertions)
-- ============================================================================

-- Get expected block hash for a given block number
-- This matches the hash generation pattern used in create_blocks()
CREATE OR REPLACE FUNCTION test.expected_block_hash(
    block_num INT,
    fork_id INT DEFAULT NULL
)
RETURNS BYTEA
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    hash_suffix TEXT;
BEGIN
    IF fork_id IS NULL THEN
        hash_suffix := lpad(to_hex(block_num * 16), 2, '0');
    ELSE
        hash_suffix := lpad(to_hex(block_num * 16 + fork_id), 2, '0');
    END IF;
    RETURN decode('BADD' || hash_suffix, 'hex');
END;
$BODY$;

COMMENT ON FUNCTION test.expected_block_hash(INT, INT) IS
'Returns the expected block hash for a given block number (and optional fork_id).
Use in assertions to verify block data without hardcoding hex values.
Example: ASSERT hash = test.expected_block_hash(5) OR test.expected_block_hash(5, 2) for fork 2';


-- Get expected prev hash for a given block number
CREATE OR REPLACE FUNCTION test.expected_prev_hash(
    block_num INT,
    fork_id INT DEFAULT NULL
)
RETURNS BYTEA
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    prev_suffix TEXT;
BEGIN
    IF fork_id IS NULL THEN
        prev_suffix := lpad(to_hex(block_num * 16), 2, '0');
    ELSE
        prev_suffix := lpad(to_hex(block_num * 16 + fork_id), 2, '0');
    END IF;
    RETURN decode('CAFE' || prev_suffix, 'hex');
END;
$BODY$;

COMMENT ON FUNCTION test.expected_prev_hash(INT, INT) IS
'Returns the expected prev hash for a given block number (and optional fork_id).
Use in assertions to verify block data without hardcoding hex values.';


-- Get expected transaction hash for a given block number
CREATE OR REPLACE FUNCTION test.expected_trx_hash(
    block_num INT,
    fork_id INT DEFAULT NULL
)
RETURNS BYTEA
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    hash_suffix TEXT;
BEGIN
    IF fork_id IS NULL THEN
        hash_suffix := lpad(to_hex(block_num * 16), 2, '0');
    ELSE
        hash_suffix := lpad(to_hex(block_num * 16 + fork_id), 2, '0');
    END IF;
    RETURN decode('DEED' || hash_suffix, 'hex');
END;
$BODY$;

COMMENT ON FUNCTION test.expected_trx_hash(INT, INT) IS
'Returns the expected transaction hash for a given block number (and optional fork_id).';


-- Get expected timestamp for a given block number
CREATE OR REPLACE FUNCTION test.expected_block_timestamp(
    block_num INT,
    base_time TIMESTAMP DEFAULT '2016-06-22 19:10:21-07'::timestamp
)
RETURNS TIMESTAMP
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    RETURN base_time + ((block_num - 1) || ' seconds')::interval;
END;
$BODY$;

COMMENT ON FUNCTION test.expected_block_timestamp(INT, TIMESTAMP) IS
'Returns the expected timestamp for a given block number based on the standard time increment pattern.';


-- ============================================================================
-- SECTION 11: VIEW TEST SCENARIO BUILDERS
-- ============================================================================

-- Setup the standard scenario used by most view tests in app_api
-- This creates the exact data pattern expected by blocks_view_test, transactions_view_test, etc.
CREATE OR REPLACE FUNCTION test.setup_view_test_scenario()
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    -- Create forks 2 and 3
    INSERT INTO hafd.fork(id, block_num, time_of_fork)
    VALUES (2, 6, '2020-06-22 19:10:25-07'::timestamp),
           (3, 7, '2020-06-22 19:10:25-07'::timestamp);

    -- Create irreversible blocks 1-5 (fork_id=0)
    PERFORM test.create_blocks(1, 5);

    -- Create initminer account (fork_id=0)
    INSERT INTO hafd.accounts(id, name, block_id)
    VALUES (5, 'initminer', hafd.make_block_id(1, 0));

    -- Reversible blocks for fork 1: blocks 4-6
    PERFORM test.create_blocks_reversible(4, hafd.make_block_id(6, 0), 1);
    -- Blocks 7-9 for fork 1 (will be overridden by fork 2)
    PERFORM test.create_blocks_reversible(7, hafd.make_block_id(9, 0), 1);

    -- Reversible blocks for fork 2: blocks 7-9
    PERFORM test.create_blocks_reversible(7, hafd.make_block_id(9, 0), 2);

    -- Reversible blocks for fork 3: blocks 8-10
    PERFORM test.create_blocks_reversible(8, hafd.make_block_id(10, 0), 3);

    -- Set consistent block
    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(5, 0);
END;
$BODY$;

COMMENT ON FUNCTION test.setup_view_test_scenario() IS
'Sets up the standard scenario for view tests (blocks_view_test, etc.):
- Forks 2 and 3 at blocks 6 and 7
- Irreversible blocks 1-5 (fork_id=0)
- Reversible blocks: fork 1 (4-9), fork 2 (7-9), fork 3 (8-10)
- consistent_block = 5';


-- Setup scenario with transactions for transaction view tests
CREATE OR REPLACE FUNCTION test.setup_transactions_view_test_scenario()
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    -- Create forks
    INSERT INTO hafd.fork(id, block_num, time_of_fork)
    VALUES (2, 6, '2020-06-22 19:10:25-07'::timestamp),
           (3, 7, '2020-06-22 19:10:25-07'::timestamp);

    -- Create irreversible blocks and transactions
    PERFORM test.create_blocks(1, 5);
    INSERT INTO hafd.accounts(id, name, block_id)
    VALUES (5, 'initminer', hafd.make_block_id(1, 0));
    PERFORM test.create_transactions(1, 5);

    -- Reversible blocks and transactions for fork 1
    PERFORM test.create_blocks_reversible(4, hafd.make_block_id(9, 0), 1);
    PERFORM test.create_transactions_reversible(4, hafd.make_block_id(9, 0), 1);

    -- Reversible blocks and transactions for fork 2
    PERFORM test.create_blocks_reversible(7, hafd.make_block_id(9, 0), 2);
    PERFORM test.create_transactions_reversible(7, hafd.make_block_id(9, 0), 2);

    -- Reversible blocks and transactions for fork 3
    PERFORM test.create_blocks_reversible(8, hafd.make_block_id(10, 0), 3);
    PERFORM test.create_transactions_reversible(8, hafd.make_block_id(10, 0), 3);

    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(5, 0);
END;
$BODY$;

COMMENT ON FUNCTION test.setup_transactions_view_test_scenario() IS
'Sets up the standard scenario for transaction view tests with blocks and transactions.';


-- Setup scenario with operations for operation view tests
CREATE OR REPLACE FUNCTION test.setup_operations_view_test_scenario()
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    PERFORM test.create_operation_types();

    -- Create forks
    INSERT INTO hafd.fork(id, block_num, time_of_fork)
    VALUES (2, 6, '2020-06-22 19:10:25-07'::timestamp),
           (3, 7, '2020-06-22 19:10:25-07'::timestamp);

    -- Create irreversible data
    PERFORM test.create_blocks(1, 5);
    INSERT INTO hafd.accounts(id, name, block_id)
    VALUES (5, 'initminer', hafd.make_block_id(1, 0));
    PERFORM test.create_transactions(1, 5);
    PERFORM test.create_operations(1, 5);

    -- Reversible data for fork 1
    PERFORM test.create_blocks_reversible(4, hafd.make_block_id(9, 0), 1);
    PERFORM test.create_transactions_reversible(4, hafd.make_block_id(9, 0), 1);
    PERFORM test.create_operations_reversible(4, hafd.make_block_id(9, 0), 1);

    -- Reversible data for fork 2
    PERFORM test.create_blocks_reversible(7, hafd.make_block_id(9, 0), 2);
    PERFORM test.create_transactions_reversible(7, hafd.make_block_id(9, 0), 2);
    PERFORM test.create_operations_reversible(7, hafd.make_block_id(9, 0), 2);

    -- Reversible data for fork 3
    PERFORM test.create_blocks_reversible(8, hafd.make_block_id(10, 0), 3);
    PERFORM test.create_transactions_reversible(8, hafd.make_block_id(10, 0), 3);
    PERFORM test.create_operations_reversible(8, hafd.make_block_id(10, 0), 3);

    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(5, 0);
END;
$BODY$;

COMMENT ON FUNCTION test.setup_operations_view_test_scenario() IS
'Sets up the standard scenario for operation view tests with blocks, transactions, and operations.';


-- Setup scenario with signatures for signature view tests
CREATE OR REPLACE FUNCTION test.setup_signatures_view_test_scenario()
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    -- Create forks
    INSERT INTO hafd.fork(id, block_num, time_of_fork)
    VALUES (2, 6, '2020-06-22 19:10:25-07'::timestamp),
           (3, 7, '2020-06-22 19:10:25-07'::timestamp);

    -- Create irreversible data
    PERFORM test.create_blocks(1, 5);
    INSERT INTO hafd.accounts(id, name, block_id)
    VALUES (5, 'initminer', hafd.make_block_id(1, 0));
    PERFORM test.create_transactions(1, 5);
    PERFORM test.create_transaction_signatures(1, 5);

    -- Reversible data for fork 1
    PERFORM test.create_blocks_reversible(4, hafd.make_block_id(9, 0), 1);
    PERFORM test.create_transactions_reversible(4, hafd.make_block_id(9, 0), 1);
    PERFORM test.create_transaction_signatures_reversible(4, hafd.make_block_id(9, 0), 1);

    -- Reversible data for fork 2
    PERFORM test.create_blocks_reversible(7, hafd.make_block_id(9, 0), 2);
    PERFORM test.create_transactions_reversible(7, hafd.make_block_id(9, 0), 2);
    PERFORM test.create_transaction_signatures_reversible(7, hafd.make_block_id(9, 0), 2);

    -- Reversible data for fork 3
    PERFORM test.create_blocks_reversible(8, hafd.make_block_id(10, 0), 3);
    PERFORM test.create_transactions_reversible(8, hafd.make_block_id(10, 0), 3);
    PERFORM test.create_transaction_signatures_reversible(8, hafd.make_block_id(10, 0), 3);

    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(5, 0);
END;
$BODY$;

COMMENT ON FUNCTION test.setup_signatures_view_test_scenario() IS
'Sets up the standard scenario for signature view tests with blocks, transactions, and signatures.';


-- Setup scenario with accounts for account view tests
CREATE OR REPLACE FUNCTION test.setup_accounts_view_test_scenario()
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    -- Create forks
    INSERT INTO hafd.fork(id, block_num, time_of_fork)
    VALUES (2, 6, '2020-06-22 19:10:25-07'::timestamp),
           (3, 7, '2020-06-22 19:10:25-07'::timestamp);

    -- Create irreversible blocks and accounts
    PERFORM test.create_blocks(1, 5);
    INSERT INTO hafd.accounts(id, name, block_id)
    VALUES (5, 'initminer', hafd.make_block_id(1, 0)),
           (6, 'alice', hafd.make_block_id(2, 0)),
           (7, 'bob', hafd.make_block_id(3, 0));

    -- Reversible blocks for fork 1
    PERFORM test.create_blocks_reversible(4, hafd.make_block_id(9, 0), 1);
    -- Reversible accounts for fork 1
    INSERT INTO hafd.accounts(id, name, block_id)
    VALUES (8, 'carol', hafd.make_block_id(7, 1)),
           (9, 'dan', hafd.make_block_id(8, 1));

    -- Reversible blocks for fork 2
    PERFORM test.create_blocks_reversible(7, hafd.make_block_id(9, 0), 2);
    INSERT INTO hafd.accounts(id, name, block_id)
    VALUES (8, 'eve', hafd.make_block_id(7, 2));

    -- Reversible blocks for fork 3
    PERFORM test.create_blocks_reversible(8, hafd.make_block_id(10, 0), 3);
    INSERT INTO hafd.accounts(id, name, block_id)
    VALUES (8, 'frank', hafd.make_block_id(8, 3)),
           (9, 'grace', hafd.make_block_id(9, 3));

    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(5, 0);
END;
$BODY$;

COMMENT ON FUNCTION test.setup_accounts_view_test_scenario() IS
'Sets up the standard scenario for account view tests with blocks and accounts.';


-- Setup scenario with account operations for account_operations view tests
CREATE OR REPLACE FUNCTION test.setup_account_operations_view_test_scenario()
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    PERFORM test.create_operation_types();

    -- Create forks
    INSERT INTO hafd.fork(id, block_num, time_of_fork)
    VALUES (2, 6, '2020-06-22 19:10:25-07'::timestamp),
           (3, 7, '2020-06-22 19:10:25-07'::timestamp);

    -- Create irreversible data
    PERFORM test.create_blocks(1, 5);
    INSERT INTO hafd.accounts(id, name, block_id)
    VALUES (5, 'initminer', hafd.make_block_id(1, 0)),
           (6, 'alice', hafd.make_block_id(2, 0));
    PERFORM test.create_transactions(1, 5);
    PERFORM test.create_operations(1, 5);
    PERFORM test.create_account_operations(1, hafd.make_block_id(5, 0), 5);  -- for initminer

    -- Reversible data for fork 1
    PERFORM test.create_blocks_reversible(4, hafd.make_block_id(9, 0), 1);
    PERFORM test.create_transactions_reversible(4, hafd.make_block_id(9, 0), 1);
    PERFORM test.create_operations_reversible(4, hafd.make_block_id(9, 0), 1);
    PERFORM test.create_account_operations_reversible(4, 9, 5, 1);

    -- Reversible data for fork 2
    PERFORM test.create_blocks_reversible(7, hafd.make_block_id(9, 0), 2);
    PERFORM test.create_transactions_reversible(7, hafd.make_block_id(9, 0), 2);
    PERFORM test.create_operations_reversible(7, hafd.make_block_id(9, 0), 2);
    PERFORM test.create_account_operations_reversible(7, 9, 5, 2);

    -- Reversible data for fork 3
    PERFORM test.create_blocks_reversible(8, hafd.make_block_id(10, 0), 3);
    PERFORM test.create_transactions_reversible(8, hafd.make_block_id(10, 0), 3);
    PERFORM test.create_operations_reversible(8, hafd.make_block_id(10, 0), 3);
    PERFORM test.create_account_operations_reversible(8, 10, 5, 3);

    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(5, 0);
END;
$BODY$;

COMMENT ON FUNCTION test.setup_account_operations_view_test_scenario() IS
'Sets up the standard scenario for account_operations view tests.';


-- Setup scenario with applied hardforks
CREATE OR REPLACE FUNCTION test.setup_applied_hardforks_view_test_scenario()
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    PERFORM test.create_operation_types();

    -- Create forks
    INSERT INTO hafd.fork(id, block_num, time_of_fork)
    VALUES (2, 6, '2020-06-22 19:10:25-07'::timestamp),
           (3, 7, '2020-06-22 19:10:25-07'::timestamp);

    -- Create irreversible data
    PERFORM test.create_blocks(1, 5);
    INSERT INTO hafd.accounts(id, name, block_id)
    VALUES (5, 'initminer', hafd.make_block_id(1, 0));
    PERFORM test.create_transactions(1, 5);
    PERFORM test.create_operations(1, 5);
    PERFORM test.create_applied_hardforks(1, 5);

    -- Reversible data for fork 1
    PERFORM test.create_blocks_reversible(4, hafd.make_block_id(9, 0), 1);
    PERFORM test.create_transactions_reversible(4, hafd.make_block_id(9, 0), 1);
    PERFORM test.create_operations_reversible(4, hafd.make_block_id(9, 0), 1);
    PERFORM test.create_applied_hardforks_reversible(4, hafd.make_block_id(9, 0), 1);

    -- Reversible data for fork 2
    PERFORM test.create_blocks_reversible(7, hafd.make_block_id(9, 0), 2);
    PERFORM test.create_transactions_reversible(7, hafd.make_block_id(9, 0), 2);
    PERFORM test.create_operations_reversible(7, hafd.make_block_id(9, 0), 2);
    PERFORM test.create_applied_hardforks_reversible(7, hafd.make_block_id(9, 0), 2);

    -- Reversible data for fork 3
    PERFORM test.create_blocks_reversible(8, hafd.make_block_id(10, 0), 3);
    PERFORM test.create_transactions_reversible(8, hafd.make_block_id(10, 0), 3);
    PERFORM test.create_operations_reversible(8, hafd.make_block_id(10, 0), 3);
    PERFORM test.create_applied_hardforks_reversible(8, hafd.make_block_id(10, 0), 3);

    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(5, 0);
END;
$BODY$;

COMMENT ON FUNCTION test.setup_applied_hardforks_view_test_scenario() IS
'Sets up the standard scenario for applied_hardforks view tests.';


-- ============================================================================
-- Documentation and Usage Examples
-- ============================================================================

COMMENT ON SCHEMA test IS
'Test utilities schema containing helper functions for HAF functional tests.

NOTE: This version works with unified tables using block_id encoding.
There are no separate *_reversible tables. All data goes into unified tables
with block_id = make_block_id(block_num, fork_id).

USAGE EXAMPLES:

1. Simple blockchain setup:
   SELECT test.setup_simple_blockchain(8);

2. Standard fork scenario (most common):
   SELECT test.setup_standard_fork_scenario();

3. Custom scenario with specific requirements:
   SELECT test.create_operation_types();
   SELECT test.create_accounts();
   SELECT test.create_blocks(1, 10);
   SELECT test.create_transactions(1, 10);

4. Complete test blockchain with forks:
   SELECT test.create_test_blockchain(
       irreversible_blocks => 5,
       reversible_blocks_per_fork => 3,
       fork_count => 2,
       include_all_data => true
   );

5. Granular control:
   SELECT test.create_operation_types();
   SELECT test.create_accounts(start_id => 10, account_names => ARRAY[''alice'', ''bob'', ''charlie'']);
   SELECT test.create_irreversible_data(
       end_block => 5,
       include_transactions => true,
       include_operations => true,
       include_signatures => false
   );

See function comments for detailed parameter documentation.
';
