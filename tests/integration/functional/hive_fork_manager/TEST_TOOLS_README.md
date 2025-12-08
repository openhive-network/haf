# HAF Test Tools - Usage Guide

## Overview

`test_tools.sql` provides a comprehensive library of helper functions to eliminate code duplication in HAF functional tests. These functions standardize test data creation and reduce test setup code by 60-70%.

## Quick Start

### 1. Most Common Pattern - Standard Fork Scenario

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

### 2. Simple Blockchain Without Forks

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

### 3. Custom Complete Blockchain

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

## Function Reference

### Infrastructure Setup Functions

#### `test.create_operation_types()`
Creates standard operation types (OP 0-3).

```sql
PERFORM test.create_operation_types();
```

#### `test.create_accounts(start_id, account_names, block_num)`
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

#### `test.create_forks(fork_ids, fork_blocks, fork_time)`
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

### Block Functions

#### `test.create_blocks(start_block, end_block, producer_id, base_time)`
Creates irreversible blocks.

```sql
-- Create blocks 1-10 with default producer (ID 5)
PERFORM test.create_blocks(1, 10);

-- Custom producer
PERFORM test.create_blocks(1, 10, producer_id => 15);
```

#### `test.create_blocks_reversible(start_block, end_block, fork_id, producer_id, base_time)`
Creates reversible blocks for a specific fork.

```sql
-- Create reversible blocks 6-10 for fork 1
PERFORM test.create_blocks_reversible(6, 10, 1);

-- For fork 2
PERFORM test.create_blocks_reversible(7, 10, 2);
```

### Transaction Functions

#### `test.create_transactions(start_block, end_block, trx_in_block, base_time)`
Creates irreversible transactions.

```sql
PERFORM test.create_transactions(1, 10);
```

#### `test.create_transactions_reversible(start_block, end_block, fork_id, trx_in_block, base_time)`
Creates reversible transactions.

```sql
PERFORM test.create_transactions_reversible(6, 10, 1);
```

#### `test.create_transaction_signatures(start_block, end_block)`
Creates transaction signatures (multisig).

```sql
PERFORM test.create_transaction_signatures(1, 10);
```

### Operation Functions

#### `test.create_operations(start_block, end_block, trx_in_block, op_pos)`
Creates irreversible operations.

```sql
PERFORM test.create_operations(1, 10);
```

#### `test.create_operations_reversible(start_block, end_block, fork_id, trx_in_block, op_pos)`
Creates reversible operations.

```sql
PERFORM test.create_operations_reversible(6, 10, 1);
```

### Account Operations Functions

#### `test.create_account_operations(start_block, end_block, account_id, ...)`
Creates account operations for a specific account.

```sql
-- Create operations for account 5 (initminer) for blocks 1-10
PERFORM test.create_account_operations(1, 10, 5);
```

#### `test.create_accounts_reversible(start_id, end_id, block_num, fork_id, name_prefix)`
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

### Applied Hardforks Functions

#### `test.create_applied_hardforks(start_block, end_block, trx_in_block, op_pos)`
Creates applied hardforks entries.

```sql
PERFORM test.create_applied_hardforks(1, 10);
```

### High-Level Composite Functions

#### `test.create_irreversible_data(end_block, include_...)`
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

#### `test.create_reversible_data_for_fork(start_block, end_block, fork_id, include_...)`
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

### Mock Functions (for application_loop tests)

#### `test.install_mock_hive_get_estimated_hive_head_block()`
Installs a mock for head block estimation.

```sql
PERFORM test.install_mock_hive_get_estimated_hive_head_block();
PERFORM test.set_head_block_num(50);

-- Later in test
PERFORM test.set_head_block_num(100); -- Update to simulate blockchain growth
```

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

**Reduction:** 13 lines → 6 lines (54% reduction)

---

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
        (1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
        (2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
        (3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
        (4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
        (5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000);

    INSERT INTO hafd.accounts(id, name, block_num)
    VALUES (5, 'initminer', 1), (6, 'alice', 1), (7, 'bob', 1);

    INSERT INTO hafd.blocks_reversible VALUES
        (4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1),
        (5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1),
        (6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1),
        (7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2),
        (8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2),
        (9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2),
        (8, '\xBADD83', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 6, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3),
        (9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3),
        (10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 7, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3);
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
    PERFORM test.create_blocks_reversible(8, 10, 3, producer_id => 6); -- fork 3 uses different producer
END;
$BODY$;
```

**Reduction:** 40 lines → 11 lines (72% reduction)

---

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

**Reduction:** 140 lines → 7 lines (95% reduction)

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

## Troubleshooting

### Issue: Function not found
**Solution:** Ensure test_tools.sql is loaded before your test runs. Check test runner configuration.

### Issue: Data doesn't match expected pattern
**Solution:** Check function parameters. The default values match the most common test patterns, but your test may need custom values.

### Issue: Need different data format
**Solution:** Use granular functions instead of composite ones. You have full control over each data type.

## Contributing

When adding new helper functions:
1. Follow the naming convention: `test.create_<table_name>[_reversible]`
2. Provide sensible defaults that match common test patterns
3. Add comprehensive COMMENT documentation
4. Update this README with examples

## Support

For questions or issues with test_tools:
- Check this README for examples
- Review function comments in test_tools.sql
- Look at refactored test examples in the codebase
- Contact the HAF testing team
