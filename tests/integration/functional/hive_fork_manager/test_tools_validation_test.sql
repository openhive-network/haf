-- Test to validate test_tools.sql functionality
-- This test verifies that all test utility functions work correctly
-- Updated for unified tables with block_id encoding (no *_reversible tables)

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
    -- In unified table model, these create blocks with fork_id > 0
    PERFORM test.create_blocks_reversible(4, 7, 1);
    PERFORM test.create_transactions_reversible(4, 7, 1);
    PERFORM test.create_operations_reversible(4, 7, 1);

    PERFORM test.create_blocks_reversible(7, 9, 2);
    PERFORM test.create_transactions_reversible(7, 9, 2);
    PERFORM test.create_operations_reversible(7, 9, 2);
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

    -- Verify forks were created (fork #1 always exists by default, plus 2 more from create_forks())
    ASSERT (SELECT COUNT(*) FROM hafd.fork) = 3,
        'Expected 3 forks (fork #1 + 2 created by test)';
    ASSERT EXISTS (SELECT FROM hafd.fork WHERE id = 1),
        'Missing fork 1 (default fork)';
    ASSERT EXISTS (SELECT FROM hafd.fork WHERE id = 2 AND block_num = 6),
        'Missing fork 2 at block 6';
    ASSERT EXISTS (SELECT FROM hafd.fork WHERE id = 3 AND block_num = 7),
        'Missing fork 3 at block 7';

    -- Verify irreversible blocks were created (fork_id=0)
    ASSERT (SELECT COUNT(*) FROM hafd.blocks 
            WHERE hafd.block_id_to_num(block_id) BETWEEN 1 AND 9
            AND hafd.block_id_to_fork(block_id) = 0) = 9,
        'Expected 9 irreversible blocks (fork_id=0)';

    -- Verify transactions were created
    ASSERT (SELECT COUNT(*) FROM hafd.transactions 
            WHERE hafd.block_id_to_num(block_id) BETWEEN 1 AND 5
            AND hafd.block_id_to_fork(block_id) = 0) = 5,
        'Expected 5 irreversible transactions';

    -- Verify operations were created
    ASSERT (SELECT COUNT(*) FROM hafd.operations 
            WHERE hafd.block_id_to_num(block_id) BETWEEN 1 AND 5
            AND hafd.block_id_to_fork(block_id) = 0) = 5,
        'Expected 5 irreversible operations';

    -- Verify reversible blocks for fork 1 (stored in same table with fork_id=1)
    ASSERT (SELECT COUNT(*) FROM hafd.blocks 
            WHERE hafd.block_id_to_fork(block_id) = 1 
            AND hafd.block_id_to_num(block_id) BETWEEN 4 AND 7) = 4,
        'Expected 4 blocks for fork 1 (blocks 4-7)';

    -- Verify reversible transactions for fork 1
    ASSERT (SELECT COUNT(*) FROM hafd.transactions 
            WHERE hafd.block_id_to_fork(block_id) = 1 
            AND hafd.block_id_to_num(block_id) BETWEEN 4 AND 7) = 4,
        'Expected 4 transactions for fork 1';

    -- Verify reversible operations for fork 1
    ASSERT (SELECT COUNT(*) FROM hafd.operations 
            WHERE hafd.block_id_to_fork(block_id) = 1) = 4,
        'Expected 4 operations for fork 1';

    -- Verify reversible blocks for fork 2
    ASSERT (SELECT COUNT(*) FROM hafd.blocks 
            WHERE hafd.block_id_to_fork(block_id) = 2 
            AND hafd.block_id_to_num(block_id) BETWEEN 7 AND 9) = 3,
        'Expected 3 blocks for fork 2 (blocks 7-9)';

    -- Verify test schema and functions exist
    ASSERT EXISTS (SELECT FROM pg_namespace WHERE nspname = 'test'),
        'Test schema was not created';

    ASSERT (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'test') >= 20,
        'Expected at least 20 functions in test schema';

    RAISE NOTICE 'All test_tools.sql validation checks passed!';
END;
$BODY$;
