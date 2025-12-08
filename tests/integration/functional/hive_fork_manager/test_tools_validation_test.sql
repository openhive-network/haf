-- Test to validate test_tools.sql functionality
-- This test verifies that all test utility functions work correctly

-- First, load test_tools.sql
\ir test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Test should start with clean state
    -- test_tools.sql creates the test schema
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Test 1: Basic infrastructure setup
    PERFORM test.create_operation_types();

    -- Test 2: Create simple blockchain (blocks must be created first for FK constraints)
    -- Create blocks 1-9 (forks will reference blocks 6 and 7)
    PERFORM test.create_blocks(1, 9);

    -- Create forks after blocks exist (forks reference blocks 6 and 7)
    PERFORM test.create_forks();

    PERFORM test.create_accounts();  -- After blocks due to FK
    PERFORM test.create_transactions(1, 5);
    PERFORM test.create_operations(1, 5);

    -- Test 3: Create reversible data for multiple forks
    PERFORM test.create_blocks_reversible(4, 7, 1);
    PERFORM test.create_transactions_reversible(4, 7, 1);
    PERFORM test.create_operations_reversible(4, 7, 1);

    PERFORM test.create_blocks_reversible(7, 9, 2);
    PERFORM test.create_transactions_reversible(7, 9, 2);
    PERFORM test.create_operations_reversible(7, 9, 2);

    -- Test 4: High-level function
    -- Note: This would conflict with data already created, so we'll skip it
    -- PERFORM test.setup_simple_blockchain(3);
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Verify operation types were created
    ASSERT (SELECT COUNT(*) FROM hafd.operation_types) = 4,
        'Expected 4 operation types';

    -- Verify accounts were created
    ASSERT (SELECT COUNT(*) FROM hafd.accounts WHERE id >= 5) = 3,
        'Expected 3 accounts (initminer, alice, bob)';
    ASSERT EXISTS (SELECT FROM hafd.accounts WHERE name = 'initminer'),
        'Missing initminer account';
    ASSERT EXISTS (SELECT FROM hafd.accounts WHERE name = 'alice'),
        'Missing alice account';
    ASSERT EXISTS (SELECT FROM hafd.accounts WHERE name = 'bob'),
        'Missing bob account';

    -- Verify forks were created
    ASSERT (SELECT COUNT(*) FROM hafd.fork) = 2,
        'Expected 2 forks';
    ASSERT EXISTS (SELECT FROM hafd.fork WHERE id = 2 AND block_num = 6),
        'Missing fork 2 at block 6';
    ASSERT EXISTS (SELECT FROM hafd.fork WHERE id = 3 AND block_num = 7),
        'Missing fork 3 at block 7';

    -- Verify irreversible blocks were created
    ASSERT (SELECT COUNT(*) FROM hafd.blocks WHERE num BETWEEN 1 AND 9) = 9,
        'Expected 9 irreversible blocks';

    -- Verify transactions were created
    ASSERT (SELECT COUNT(*) FROM hafd.transactions WHERE block_num BETWEEN 1 AND 5) = 5,
        'Expected 5 transactions';

    -- Verify operations were created
    ASSERT (SELECT COUNT(*) FROM hafd.operations WHERE hafd.operation_block_num(id) BETWEEN 1 AND 5) = 5,
        'Expected 5 operations';

    -- Verify reversible blocks for fork 1
    ASSERT (SELECT COUNT(*) FROM hafd.blocks_reversible WHERE fork_id = 1 AND num BETWEEN 4 AND 7) = 4,
        'Expected 4 reversible blocks for fork 1';

    -- Verify reversible transactions for fork 1
    ASSERT (SELECT COUNT(*) FROM hafd.transactions_reversible WHERE fork_id = 1 AND block_num BETWEEN 4 AND 7) = 4,
        'Expected 4 reversible transactions for fork 1';

    -- Verify reversible operations for fork 1
    ASSERT (SELECT COUNT(*) FROM hafd.operations_reversible WHERE fork_id = 1) = 4,
        'Expected 4 reversible operations for fork 1';

    -- Verify reversible blocks for fork 2
    ASSERT (SELECT COUNT(*) FROM hafd.blocks_reversible WHERE fork_id = 2 AND num BETWEEN 7 AND 9) = 3,
        'Expected 3 reversible blocks for fork 2';

    -- Verify test schema and functions exist
    ASSERT EXISTS (SELECT FROM pg_namespace WHERE nspname = 'test'),
        'Test schema was not created';

    ASSERT (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'test') >= 40,
        'Expected at least 40 functions in test schema';

    RAISE NOTICE 'All test_tools.sql validation checks passed!';
END;
$BODY$;
