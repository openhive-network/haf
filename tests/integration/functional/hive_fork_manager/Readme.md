# HAF Hive Fork Manager Tests

This directory contains functional tests for the Hive Fork Manager, including integration tests and examples.

## Examples

The `hive_fork_manager` test introduces a new type of test that checks if examples from the `src/hive_fork_manager/doc/examples` folder work correctly.

The CMake macro `ADD_EXAMPLES_FUNCTIONAL_TESTS(<relative_path_to_script>)` adds a test that calls [test_examples.sh](test_examples.sh) to perform the following operations:

1. Prepares the database for the application - block data and events queue with [./examples/prepare_data.sql](./examples/prepare_data.sql).
2. Executes the test script with passing it a directory with the examples.

### Python Dependencies

For tests that check application examples, Python 3 is required with the following modules installed:

- `pexpect`
- `psycopg2`
- `sqlalchemy`

---

## Test Tools Library

### Overview

`test_tools.sql` provides a comprehensive library of helper functions to eliminate code duplication in HAF functional tests. These functions standardize test data creation and reduce test setup code by 60-70%.

### Quick Start

#### Most Common Pattern - Standard Fork Scenario

```sql
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    -- This single function call replaces 100+ lines of INSERT statements
    PERFORM test.setup_standard_fork_scenario();

    -- Add any test-specific data here
END;
$BODY$;
```

**What it creates:**
- Operation types (OP 0-3)
- Standard accounts (initminer, alice, bob with IDs 5, 6, 7)
- Forks 2 and 3 at blocks 6 and 7
- 5 irreversible blocks with transactions and operations
- Reversible data for 3 forks (blocks 4-10 for fork 1, 7-10 for fork 2, 8-10 for fork 3)

#### Simple Blockchain Without Forks

```sql
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    PERFORM test.setup_simple_blockchain(8);
    -- Creates 8 blocks with transactions and operations
END;
$BODY$;
```

#### Custom Complete Blockchain

```sql
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    PERFORM test.create_test_blockchain(
        irreversible_blocks => 10,
        reversible_blocks_per_fork => 5,
        fork_count => 3,
        include_all_data => true
    );
END;
$BODY$;
```

### Function Reference

#### Infrastructure Setup Functions

**`test.create_operation_types()`**
Creates standard operation types (OP 0-3).

```sql
PERFORM test.create_operation_types();
```

**`test.create_accounts(start_id, account_names, block_num)`**
Creates test accounts.

```sql
-- Default: Creates initminer, alice, bob starting at ID 5
PERFORM test.create_accounts();

-- Custom accounts
PERFORM test.create_accounts(
    start_id => 10,
    account_names => ARRAY['alice', 'bob', 'charlie', 'dave'],
    block_num => 1
);
```

**`test.create_forks(fork_ids, fork_blocks, fork_time)`**
Creates fork entries.

```sql
-- Default: Forks 2 and 3 at blocks 6 and 7
PERFORM test.create_forks();

-- Custom forks
PERFORM test.create_forks(
    fork_ids => ARRAY[2, 3, 4],
    fork_blocks => ARRAY[10, 15, 20]
);
```

#### Block Functions

**`test.create_blocks(start_block, end_block, producer_id, base_time)`**
Creates irreversible blocks.

```sql
-- Create blocks 1-10 with default producer (ID 5)
PERFORM test.create_blocks(1, 10);

-- Custom producer
PERFORM test.create_blocks(1, 10, producer_id => 15);
```

**`test.create_blocks_reversible(start_block, end_block, fork_id, producer_id, base_time)`**
Creates reversible blocks for a specific fork.

```sql
-- Create reversible blocks 6-10 for fork 1
PERFORM test.create_blocks_reversible(6, 10, 1);

-- For fork 2
PERFORM test.create_blocks_reversible(7, 10, 2);
```

#### Transaction Functions

**`test.create_transactions(start_block, end_block, trx_in_block, base_time)`**
Creates irreversible transactions.

```sql
PERFORM test.create_transactions(1, 10);
```

**`test.create_transactions_reversible(start_block, end_block, fork_id, trx_in_block, base_time)`**
Creates reversible transactions.

```sql
PERFORM test.create_transactions_reversible(6, 10, 1);
```

**`test.create_transaction_signatures(start_block, end_block)`**
Creates transaction signatures (multisig).

```sql
PERFORM test.create_transaction_signatures(1, 10);
```

#### Operation Functions

**`test.create_operations(start_block, end_block, trx_in_block, op_pos)`**
Creates irreversible operations.

```sql
PERFORM test.create_operations(1, 10);
```

**`test.create_operations_reversible(start_block, end_block, fork_id, trx_in_block, op_pos)`**
Creates reversible operations.

```sql
PERFORM test.create_operations_reversible(6, 10, 1);
```

#### Account Operations Functions

**`test.create_account_operations(start_block, end_block, account_id, ...)`**
Creates account operations for a specific account.

```sql
-- Create operations for account 5 (initminer) for blocks 1-10
PERFORM test.create_account_operations(1, 10, 5);
```

**`test.create_accounts_reversible(start_id, end_id, block_num, fork_id, name_prefix)`**
Creates reversible accounts.

```sql
PERFORM test.create_accounts_reversible(
    start_id => 10,
    end_id => 15,
    block_num => 7,
    fork_id => 2,
    name_prefix => 'user'
);
```

#### Applied Hardforks Functions

**`test.create_applied_hardforks(start_block, end_block, trx_in_block, op_pos)`**
Creates applied hardforks entries.

```sql
PERFORM test.create_applied_hardforks(1, 10);
```

#### High-Level Composite Functions

**`test.create_irreversible_data(end_block, include_...)`**
Creates complete irreversible blockchain data with granular control.

```sql
PERFORM test.create_irreversible_data(
    end_block => 5,
    include_accounts => FALSE,  -- already created separately
    include_transactions => TRUE,
    include_operations => TRUE,
    include_signatures => TRUE,
    include_hardforks => FALSE,
    include_account_operations => FALSE
);
```

**`test.create_reversible_data_for_fork(start_block, end_block, fork_id, include_...)`**
Creates complete reversible data for a specific fork.

```sql
PERFORM test.create_reversible_data_for_fork(
    start_block => 6,
    end_block => 10,
    fork_id => 1,
    include_accounts => TRUE,
    include_transactions => TRUE,
    include_operations => TRUE,
    include_signatures => TRUE,
    include_hardforks => TRUE,
    include_account_operations => TRUE
);
```

#### Mock Functions (for application_loop tests)

**`test.install_mock_hive_get_estimated_hive_head_block()`**
Installs a mock for head block estimation.

```sql
PERFORM test.install_mock_hive_get_estimated_hive_head_block();
PERFORM test.set_head_block_num(50);

-- Later in test
PERFORM test.set_head_block_num(100); -- Update to simulate blockchain growth
```

---

## Integration Instructions

### Option 1: Load via Test Setup Script (Recommended)

Most HAF tests use setup scripts. Modify the setup to include test_tools.sql.

#### 1. Locate Test Setup Script

Common locations:
```bash
/home/dev/src/haf/tests/integration/functional/setup_db.sql
/home/dev/src/haf/tests/integration/functional/hive_fork_manager/setup.sql
```

#### 2. Add test_tools.sql to Setup

Add this line to the setup script (after HAF schema is created):

```sql
-- Load test utilities
\i /home/dev/src/haf/tests/integration/functional/hive_fork_manager/test_tools.sql
```

Or use project-relative path:
```sql
\i :project_dir/tests/integration/functional/hive_fork_manager/test_tools.sql
```

#### 3. Verify Integration

Run a simple test to verify:

```sql
-- Test if functions are available
SELECT test.create_operation_types();
SELECT COUNT(*) FROM hafd.operation_types; -- Should return 4
```

### Option 2: Load via CMake Configuration

If tests are run via CMake/CTest, modify the CMakeLists.txt.

#### 1. Edit CMakeLists.txt

File: `/home/dev/src/haf/tests/integration/functional/hive_fork_manager/CMakeLists.txt`

Add at the beginning (after any existing setup):

```cmake
# Load test utilities for all tests
SET(TEST_TOOLS_PATH ${CMAKE_CURRENT_SOURCE_DIR}/test_tools.sql)

# Function to add test_tools to test setup
MACRO(ADD_TEST_TOOLS_SETUP)
    # This ensures test_tools.sql is loaded before test execution
    # Implementation depends on your test framework
ENDMACRO()
```

#### 2. Modify Test Execution

Update the test execution command to include test_tools.sql loading.

Example for psql-based tests:
```cmake
ADD_TEST(NAME ${test_name}
    COMMAND psql
        -f ${TEST_TOOLS_PATH}  # Load test_tools first
        -f ${test_file}         # Then run the test
        # ... other parameters
)
```

### Option 3: Load in Each Test (Not Recommended)

For quick testing or when modifying test framework is not feasible:

```sql
-- Add at the beginning of each test file
\i /home/dev/src/haf/tests/integration/functional/hive_fork_manager/test_tools.sql

-- Then use functions normally
CREATE OR REPLACE PROCEDURE haf_admin_test_given() AS $BODY$
BEGIN
    PERFORM test.setup_standard_fork_scenario();
END;
$BODY$;
```

**Note:** This creates duplication and is harder to maintain. Use Options 1 or 2 instead.

### Verification After Integration

#### Test 1: Check Functions Exist

```sql
-- Should list all test.* functions
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'test'
ORDER BY routine_name;
```

Expected output should include:
- create_operation_types
- create_forks
- create_accounts
- create_blocks
- setup_standard_fork_scenario
- ... and 35+ more functions

#### Test 2: Run a Simple Test

```sql
-- Create a test database
CREATE DATABASE test_integration;
\c test_integration

-- Load HAF extension
CREATE EXTENSION hive_fork_manager;

-- Load test_tools
\i /path/to/test_tools.sql

-- Test basic functionality
BEGIN;
    PERFORM test.setup_simple_blockchain(5);
    SELECT COUNT(*) FROM hafd.blocks; -- Should be 5
ROLLBACK;
```

#### Test 3: Run Existing Test Suite

```bash
# Run one test to verify integration
ctest -R test.functional.hive_fork_manager.hived_api.schema_test -V

# If successful, run full suite
ctest -R test.functional.hive_fork_manager -j4
```

---

## Migration Examples

### Example 1: Simple Test Migration

**Before:**
```sql
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE)
         , (1, 'OP 1', FALSE)
         , (2, 'OP 2', FALSE)
         , (3, 'OP 3', TRUE);

    INSERT INTO hafd.blocks
    VALUES (1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000);

    INSERT INTO hafd.accounts(id, name, block_num)
    VALUES (5, 'initminer', 1);

    PERFORM hive.end_massive_sync(1);
END;
$BODY$;
```

**After:**
```sql
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    PERFORM test.create_operation_types();
    PERFORM test.create_accounts(account_names => ARRAY['initminer']);
    PERFORM test.create_blocks(1, 1);

    PERFORM hive.end_massive_sync(1);
END;
$BODY$;
```

**Reduction:** 13 lines -> 6 lines (54% reduction)

### Example 2: Complex Fork Test Migration

**Before (from copy_blocks_to_irreversible.sql):**
```sql
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    INSERT INTO hafd.fork(id, block_num, time_of_fork)
    VALUES (2, 6, '2020-06-22 19:10:25-07'::timestamp),
           (3, 7, '2020-06-22 19:10:25-07'::timestamp);

    INSERT INTO hafd.blocks VALUES
        (1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, ...),
        (2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, ...),
        -- ... 3 more blocks
        (5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, ...);

    INSERT INTO hafd.accounts(id, name, block_num)
    VALUES (5, 'initminer', 1), (6, 'alice', 1), (7, 'bob', 1);

    INSERT INTO hafd.blocks_reversible VALUES
        -- ... 9 reversible blocks across 3 forks
        ;
END;
$BODY$;
```

**After:**
```sql
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    -- Setup infrastructure
    PERFORM test.create_forks();
    PERFORM test.create_accounts();

    -- Create irreversible blocks 1-5
    PERFORM test.create_blocks(1, 5);

    -- Create reversible blocks for 3 forks
    PERFORM test.create_blocks_reversible(4, 6, 1);
    PERFORM test.create_blocks_reversible(7, 9, 2);
    PERFORM test.create_blocks_reversible(8, 10, 3, producer_id => 6);
END;
$BODY$;
```

**Reduction:** 40 lines -> 11 lines (72% reduction)

### Example 3: Complete Data Scenario

**Before (from copy_operations_to_irreversible_test.sql - 140 lines):**
```sql
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context(_name => 'context', _schema => 'a');

    INSERT INTO hafd.operation_types VALUES ...;
    INSERT INTO hafd.fork VALUES ...;
    INSERT INTO hafd.blocks VALUES ... (8 blocks);
    INSERT INTO hafd.accounts VALUES ... (3 accounts);
    INSERT INTO hafd.transactions VALUES ... (5 transactions);
    INSERT INTO hafd.operations VALUES ... (5 operations);
    INSERT INTO hafd.blocks_reversible VALUES ... (10 blocks across 3 forks);
    INSERT INTO hafd.transactions_reversible VALUES ... (9 transactions);
    INSERT INTO hafd.operations_reversible VALUES ... (13 operations);
END;
$BODY$;
```

**After:**
```sql
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql' AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context(_name => 'context', _schema => 'a');

    PERFORM test.setup_standard_fork_scenario();
    -- That's it! All data is created with one function call
END;
$BODY$;
```

**Reduction:** 140 lines -> 7 lines (95% reduction)

---

## Best Practices

### 1. Use High-Level Functions First
Start with `setup_standard_fork_scenario()` or `setup_simple_blockchain()`. Only use granular functions when you need custom data.

### 2. Layer Your Setup
```sql
-- Infrastructure first
PERFORM test.create_operation_types();
PERFORM test.create_accounts();

-- Then data layers
PERFORM test.create_blocks(1, 10);
PERFORM test.create_transactions(1, 10);
PERFORM test.create_operations(1, 10);
```

### 3. Add Test-Specific Data After Standard Setup
```sql
-- Standard setup
PERFORM test.setup_simple_blockchain(5);

-- Test-specific customization
INSERT INTO hafd.accounts VALUES (100, 'special_account', 3);
PERFORM hive.push_block(...); -- specific test block
```

### 4. Document Deviations from Standard
```sql
-- Standard fork scenario, but with custom accounts
PERFORM test.create_operation_types();
PERFORM test.create_forks();

-- Using account IDs 15-17 instead of 5-7 for this test's specific needs
PERFORM test.create_accounts(start_id => 15);

PERFORM test.create_blocks(1, 5);
-- ... rest of setup
```

---

## Troubleshooting

### Issue: Function not found
**Solution:** Ensure test_tools.sql is loaded before your test runs. Check test runner configuration.

### Issue: "schema 'test' does not exist"
**Cause:** test_tools.sql not loaded or loaded after test execution started

**Solution:**
- Ensure test_tools.sql is loaded in setup phase
- Check load order in setup script
- Verify file path is correct

### Issue: "permission denied for schema test"
**Cause:** Test user doesn't have access to test schema

**Solution:**
```sql
-- Grant access to test schema
GRANT USAGE ON SCHEMA test TO test_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test TO test_user;
```

### Issue: Tests fail with "table hafd.xxx does not exist"
**Cause:** Test functions being called before HAF schema is initialized

**Solution:**
- Ensure HAF extension is created first
- Load test_tools.sql after HAF initialization
- Check setup script order

### Issue: Data doesn't match expected pattern
**Solution:** Check function parameters. The default values match the most common test patterns, but your test may need custom values.

### Issue: Need different data format
**Solution:** Use granular functions instead of composite ones. You have full control over each data type.

---

## Function Library Structure

### Section 1: Basic Infrastructure Setup (3 functions)
- `create_operation_types()` - Standard operation types
- `create_forks()` - Fork structure setup
- `create_accounts()` - Test account creation

### Section 2: Block Creation Functions (2 functions)
- `create_blocks()` - Irreversible blocks
- `create_blocks_reversible()` - Reversible blocks with fork support

### Section 3: Transaction Creation Functions (4 functions)
- `create_transactions()` - Irreversible transactions
- `create_transactions_reversible()` - Reversible transactions
- `create_transaction_signatures()` - Transaction multisig
- `create_transaction_signatures_reversible()` - Reversible multisig

### Section 4: Operation Creation Functions (2 functions)
- `create_operations()` - Irreversible operations
- `create_operations_reversible()` - Reversible operations

### Section 5: Account Operations Functions (3 functions)
- `create_account_operations()` - Account operation links
- `create_account_operations_reversible()` - Reversible account operations
- `create_accounts_reversible()` - Reversible accounts

### Section 6: Applied Hardforks Functions (2 functions)
- `create_applied_hardforks()` - Hardfork entries
- `create_applied_hardforks_reversible()` - Reversible hardforks

### Section 7: High-Level Composite Functions (3 functions)
- `create_irreversible_data()` - Complete irreversible blockchain
- `create_reversible_data_for_fork()` - Complete fork data
- `create_test_blockchain()` - Full blockchain with multiple forks

### Section 8: Simple Scenario Builders (2 functions)
- `setup_simple_blockchain()` - No-fork blockchain
- `setup_standard_fork_scenario()` - Most common test pattern

### Section 9: Mock and Utility Functions (2 functions)
- `install_mock_hive_get_estimated_hive_head_block()` - Mock installer
- `set_head_block_num()` - Mock value setter

---

## Expected Benefits

**Code Reduction:**
- Average: 60-70% reduction in test setup code
- Best case: 95% reduction (simple scenarios)
- Complex tests: 50-60% reduction

**Maintainability:**
- Single point of change for data structure updates
- Consistent data patterns across all tests
- Easier debugging with standard data

**Development Speed:**
- New test creation time: Reduced by 50%+
- Less copy-paste errors
- Focus on test logic, not data setup

---

## Contributing

When adding new helper functions:
1. Follow the naming convention: `test.create_<table_name>[_reversible]`
2. Provide sensible defaults that match common test patterns
3. Add comprehensive COMMENT documentation
4. Update this README with examples

## File Locations Reference

```
/home/dev/src/haf/tests/integration/functional/hive_fork_manager/
├── test_tools.sql                          # Main function library
├── Readme.md                               # This file
└── examples_refactored/
    ├── REFACTORING_GUIDE.md                # Step-by-step guide
    ├── copy_blocks_to_irreversible_REFACTORED.sql
    ├── copy_operations_to_irreversible_REFACTORED.sql
    ├── app_next_block_process_new_block_event_REFACTORED.sql
    └── two_iterations_REFACTORED.sql
```

## Support

For questions or issues with test_tools:
- Check this README for examples
- Review function comments in test_tools.sql
- Look at refactored test examples in the codebase
- Contact the HAF testing team
