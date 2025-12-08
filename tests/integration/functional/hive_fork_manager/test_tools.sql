-- HAF Test Tools: Common functions for test data setup
-- This file provides reusable functions to reduce code duplication across functional tests
-- All functions are in the 'test' schema to avoid conflicts with production code

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


-- Setup standard test accounts (irreversible)
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
BEGIN
    FOR i IN 1..array_length(account_names, 1) LOOP
        INSERT INTO hafd.accounts(id, name, block_num)
        VALUES (start_id + i - 1, account_names[i], block_num);
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_accounts(INT, TEXT[], INT) IS
'Creates test accounts in hafd.accounts table. Default creates initminer, alice, and bob starting at ID 5';


-- ============================================================================
-- SECTION 2: BLOCK CREATION FUNCTIONS
-- ============================================================================

-- Create a range of irreversible blocks
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
BEGIN
    FOR block_num IN start_block..end_block LOOP
        hash_suffix := lpad(to_hex(block_num * 16), 2, '0');
        prev_suffix := lpad(to_hex(block_num * 16), 2, '0');

        INSERT INTO hafd.blocks
        VALUES (
            block_num,
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
'Creates a range of irreversible blocks in hafd.blocks table with auto-generated hashes';


-- Create a range of reversible blocks
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
    block_num INT;
    hash_suffix TEXT;
    prev_suffix TEXT;
BEGIN
    FOR block_num IN start_block..end_block LOOP
        -- Add fork_id to hash to create unique hashes per fork
        hash_suffix := lpad(to_hex(block_num * 16 + fork_id), 2, '0');
        prev_suffix := lpad(to_hex(block_num * 16 + fork_id), 2, '0');

        INSERT INTO hafd.blocks_reversible
        VALUES (
            block_num,
            decode('BADD' || hash_suffix, 'hex'),
            decode('CAFE' || prev_suffix, 'hex'),
            base_time + ((block_num - 1) || ' seconds')::interval,
            producer_id,
            '\x4007'::bytea,
            '[]'::jsonb,
            '\x2157'::bytea,
            'STM65w',
            1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000,
            fork_id
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_blocks_reversible(INT, INT, INT, INT, TIMESTAMP) IS
'Creates a range of reversible blocks in hafd.blocks_reversible table with fork_id';


-- ============================================================================
-- SECTION 3: TRANSACTION CREATION FUNCTIONS
-- ============================================================================

-- Create irreversible transactions
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
BEGIN
    FOR block_num IN start_block..end_block LOOP
        hash_suffix := lpad(to_hex(block_num * 16), 2, '0');

        INSERT INTO hafd.transactions
        VALUES (
            block_num,
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
'Creates irreversible transactions in hafd.transactions table';


-- Create reversible transactions
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
BEGIN
    FOR block_num IN start_block..end_block LOOP
        hash_suffix := lpad(to_hex(block_num * 16 + fork_id), 2, '0');

        INSERT INTO hafd.transactions_reversible
        VALUES (
            block_num,
            trx_in_block,
            decode('DEED' || hash_suffix, 'hex'),
            101,
            100,
            base_time + ((block_num - 1) || ' seconds')::interval,
            '\xBEEF'::bytea,
            fork_id
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_transactions_reversible(INT, INT, INT, SMALLINT, TIMESTAMP) IS
'Creates reversible transactions in hafd.transactions_reversible table with fork_id';


-- Create transaction signatures (multisig) - irreversible
CREATE OR REPLACE FUNCTION test.create_transaction_signatures(
    start_block INT,
    end_block INT
)
RETURNS void
LANGUAGE 'plpgsql' AS
$BODY$
DECLARE
    block_num INT;
    trx_hash_suffix TEXT;
    sig_suffix TEXT;
BEGIN
    FOR block_num IN start_block..end_block LOOP
        trx_hash_suffix := lpad(to_hex(block_num * 16), 2, '0');
        sig_suffix := lpad(to_hex(block_num * 16), 2, '0');

        INSERT INTO hafd.transactions_multisig
        VALUES (
            decode('DEED' || trx_hash_suffix, 'hex'),
            decode('BAAD' || sig_suffix, 'hex')
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_transaction_signatures(INT, INT) IS
'Creates transaction signatures in hafd.transactions_multisig table';


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
    trx_hash_suffix TEXT;
    sig_suffix TEXT;
BEGIN
    FOR block_num IN start_block..end_block LOOP
        trx_hash_suffix := lpad(to_hex(block_num * 16 + fork_id), 2, '0');
        sig_suffix := lpad(to_hex(block_num * 16 + fork_id), 2, '0');

        INSERT INTO hafd.transactions_multisig_reversible
        VALUES (
            decode('DEED' || trx_hash_suffix, 'hex'),
            decode('BEEF' || sig_suffix, 'hex'),
            fork_id
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_transaction_signatures_reversible(INT, INT, INT) IS
'Creates reversible transaction signatures in hafd.transactions_multisig_reversible table';


-- ============================================================================
-- SECTION 4: OPERATION CREATION FUNCTIONS
-- ============================================================================

-- Create irreversible operations
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
BEGIN
    FOR block_num IN start_block..end_block LOOP
        message := 'OPERATION BLOCK ' || block_num::TEXT;

        INSERT INTO hafd.operations
        VALUES (
            hafd.operation_id(block_num, trx_in_block, op_pos),
            trx_in_block - 1,
            op_pos,
            ('{"type":"system_warning_operation","value":{"message":"' || message || '"}}')::jsonb::hafd.operation
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_operations(INT, INT, INT, INT) IS
'Creates irreversible operations in hafd.operations table';


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
BEGIN
    FOR block_num IN start_block..end_block LOOP
        message := 'OPERATION BLOCK ' || block_num::TEXT || ' FORK ' || fork_id::TEXT;

        INSERT INTO hafd.operations_reversible
        VALUES (
            hafd.operation_id(block_num, trx_in_block, op_pos),
            trx_in_block - 1,
            op_pos,
            ('{"type":"system_warning_operation","value":{"message":"' || message || '"}}')::jsonb::hafd.operation,
            fork_id
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_operations_reversible(INT, INT, INT, INT, INT) IS
'Creates reversible operations in hafd.operations_reversible table with fork_id';


-- ============================================================================
-- SECTION 5: ACCOUNT OPERATIONS FUNCTIONS
-- ============================================================================

-- Create account operations (irreversible)
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
BEGIN
    trans_acc_id := COALESCE(transacting_account_id, account_id);

    FOR block_num IN start_block..end_block LOOP
        INSERT INTO hafd.account_operations(account_id, transacting_account_id, account_op_seq_no, operation_id)
        VALUES (
            account_id,
            trans_acc_id,
            seq_no,
            hafd.operation_id(block_num, trx_in_block, op_pos)
        );
        seq_no := seq_no + 1;
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_account_operations(INT, INT, INT, INT, INT, INT) IS
'Creates account operations in hafd.account_operations table for a specific account';


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
BEGIN
    trans_acc_id := COALESCE(transacting_account_id, account_id);

    FOR block_num IN start_block..end_block LOOP
        INSERT INTO hafd.account_operations_reversible
        VALUES (
            account_id,
            trans_acc_id,
            seq_no,
            hafd.operation_id(block_num, trx_in_block, op_pos),
            fork_id
        );
        seq_no := seq_no + 1;
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_account_operations_reversible(INT, INT, INT, INT, INT, INT, INT) IS
'Creates reversible account operations with fork_id for a specific account';


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
BEGIN
    FOR acc_id IN start_id..end_id LOOP
        INSERT INTO hafd.accounts_reversible
        VALUES (
            acc_id,
            name_prefix || acc_id::TEXT,
            block_num,
            fork_id
        );
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_accounts_reversible(INT, INT, INT, INT, TEXT) IS
'Creates reversible accounts in hafd.accounts_reversible table';


-- ============================================================================
-- SECTION 6: APPLIED HARDFORKS FUNCTIONS
-- ============================================================================

-- Create applied hardforks (irreversible)
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
BEGIN
    hf_num := start_block;
    FOR block_num IN start_block..end_block LOOP
        INSERT INTO hafd.applied_hardforks
        VALUES (
            hf_num,
            block_num,
            hafd.operation_id(block_num, trx_in_block, op_pos)
        );
        hf_num := hf_num + 1;
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_applied_hardforks(INT, INT, INT, INT) IS
'Creates applied hardforks in hafd.applied_hardforks table';


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
BEGIN
    hf_num := start_block;
    FOR block_num IN start_block..end_block LOOP
        INSERT INTO hafd.applied_hardforks_reversible
        VALUES (
            hf_num,
            block_num,
            hafd.operation_id(block_num, trx_in_block, op_pos),
            fork_id
        );
        hf_num := hf_num + 1;
    END LOOP;
END;
$BODY$;

COMMENT ON FUNCTION test.create_applied_hardforks_reversible(INT, INT, INT, INT, INT) IS
'Creates reversible applied hardforks with fork_id';


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
'Creates a complete set of irreversible blockchain data up to specified block. Flags control which data types to include.';


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
    PERFORM test.create_accounts();
    PERFORM test.create_blocks(1, num_blocks);
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
    PERFORM test.create_accounts();

    -- Irreversible data (blocks 1-5)
    PERFORM test.create_blocks(1, 5);
    PERFORM test.create_transactions(1, 5);
    PERFORM test.create_operations(1, 5);

    -- Reversible data for fork 1 (main)
    PERFORM test.create_blocks_reversible(4, 10, 1);
    PERFORM test.create_transactions_reversible(4, 10, 1);
    PERFORM test.create_operations_reversible(4, 10, 1);

    -- Reversible data for fork 2
    PERFORM test.create_blocks_reversible(7, 10, 2);
    PERFORM test.create_transactions_reversible(7, 10, 2);
    PERFORM test.create_operations_reversible(7, 10, 2);

    -- Reversible data for fork 3
    PERFORM test.create_blocks_reversible(8, 10, 3);
    PERFORM test.create_transactions_reversible(8, 10, 3);
    PERFORM test.create_operations_reversible(8, 10, 3);
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
-- Documentation and Usage Examples
-- ============================================================================

COMMENT ON SCHEMA test IS
'Test utilities schema containing helper functions for HAF functional tests.

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
