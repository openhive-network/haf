# Test Refactoring Guide - Step by Step

This guide provides a systematic approach to refactoring HAF tests using test_tools.sql.

## Table of Contents
1. [Before You Start](#before-you-start)
2. [Refactoring Process](#refactoring-process)
3. [Common Patterns](#common-patterns)
4. [Edge Cases](#edge-cases)
5. [Testing Your Refactoring](#testing-your-refactoring)
6. [Example Walkthroughs](#example-walkthroughs)

---

## Before You Start

### Prerequisites
- [ ] test_tools.sql is available and loaded in test environment
- [ ] You understand the test you're refactoring (what it tests)
- [ ] You have run the original test successfully

### Quick Assessment

Ask these questions:
1. **Does the test use standard test data?** → Use `test.setup_standard_fork_scenario()`
2. **Does it create forks?** → Check if it matches standard fork pattern (forks 2 & 3 at blocks 6 & 7)
3. **Does it create only irreversible blocks?** → Use `test.setup_simple_blockchain()`
4. **Does it have custom data requirements?** → Use granular functions

---

## Refactoring Process

### Step 1: Identify Data Setup Code

Look for these patterns in `haf_admin_test_given()`:

```sql
INSERT INTO hafd.operation_types VALUES ...
INSERT INTO hafd.fork VALUES ...
INSERT INTO hafd.blocks (block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES ...
INSERT INTO hafd.accounts VALUES ...
INSERT INTO hafd.transactions VALUES ...
INSERT INTO hafd.operations VALUES ...
INSERT INTO hafd.blocks_reversible VALUES ...
INSERT INTO hafd.transactions_reversible VALUES ...
INSERT INTO hafd.operations_reversible VALUES ...
```

**Mark for refactoring**: All sequential INSERT statements for standard tables
**Keep as-is**: Test-specific logic, hive API calls, context setup, custom tables

### Step 2: Categorize the Test

#### Category A: Standard Fork Scenario (Most Common)
**Indicators:**
- Creates operation types
- Creates forks 2 and 3 at blocks 6 and 7
- Creates accounts (initminer, alice, bob)
- Creates 5-8 irreversible blocks
- Creates reversible blocks for 2-3 forks

**Refactoring:**
```sql
PERFORM test.setup_standard_fork_scenario();
```

**Examples in this codebase:**
- Most hived_api tests (copy_*_to_irreversible tests)
- Many app_api tests

#### Category B: Simple Blockchain
**Indicators:**
- No forks
- Just irreversible blocks
- Usually < 10 blocks

**Refactoring:**
```sql
PERFORM test.setup_simple_blockchain(num_blocks);
```

**Examples:**
- Simple push_block tests
- Basic context tests

#### Category C: Custom Requirements
**Indicators:**
- Non-standard fork structure
- Specific account IDs
- Custom block ranges
- Requires fine-grained control

**Refactoring:**
Use granular functions. See [Common Patterns](#common-patterns) below.

### Step 3: Replace INSERT Statements

#### For Standard Scenarios:
```sql
-- BEFORE
INSERT INTO hafd.operation_types VALUES (0, 'OP 0', FALSE), ...;
INSERT INTO hafd.fork VALUES (2, 6, ...), (3, 7, ...);
INSERT INTO hafd.accounts VALUES (5, 'initminer', 1), ...;
-- ... 50+ more lines

-- AFTER
PERFORM test.setup_standard_fork_scenario();
```

#### For Custom Scenarios:
Replace each INSERT group with corresponding function:

```sql
-- BEFORE
INSERT INTO hafd.blocks (block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (1, ...), (2, ...), (3, ...);

-- AFTER
PERFORM test.create_blocks(1, 3);
```

### Step 4: Handle Special Cases

#### Custom Values in Standard Data
If you need standard data but with custom values:

```sql
-- Standard setup first
PERFORM test.create_operation_types();
PERFORM test.create_forks();

-- Custom accounts instead of default
PERFORM test.create_accounts(
    start_id => 15,  -- Different ID range
    account_names => ARRAY['initminer', 'alice', 'bob']
);

-- Rest of standard setup
PERFORM test.create_blocks(1, 8);
```

#### Mix of Standard and Custom
```sql
-- Standard infrastructure
PERFORM test.create_operation_types();
PERFORM test.create_accounts();

-- Standard irreversible data
PERFORM test.create_blocks(1, 5);
PERFORM test.create_transactions(1, 5);

-- Custom operation with specific content
INSERT INTO hafd.operations
VALUES (hafd.operation_id(6,1,0), 0, 0,
    '{"type":"custom_op","value":{"special":"data"}}'::jsonb::hafd.operation);
```

#### Test-Specific API Calls
Keep these unchanged:
```sql
-- Keep as-is
PERFORM hive.push_block(...);
PERFORM hive.end_massive_sync(1);
PERFORM hive.back_from_fork(10);
CREATE SCHEMA A;
PERFORM hive.app_create_context(...);
```

### Step 5: Preserve Test Intent

**Critical**: The refactored test must have identical behavior.

Verify:
- [ ] Same blocks created
- [ ] Same accounts created
- [ ] Same operations created
- [ ] Same fork structure
- [ ] All test-specific data preserved
- [ ] All hive API calls preserved

---

## Common Patterns

### Pattern 1: Infrastructure Only
```sql
-- BEFORE (15 lines)
INSERT INTO hafd.operation_types VALUES ...;
INSERT INTO hafd.fork VALUES ...;
INSERT INTO hafd.accounts VALUES ...;

-- AFTER (3 lines)
PERFORM test.create_operation_types();
PERFORM test.create_forks();
PERFORM test.create_accounts();
```

### Pattern 2: Complete Irreversible Blockchain
```sql
-- BEFORE (40 lines)
INSERT INTO hafd.blocks (block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (1, ...), (2, ...), ...;
INSERT INTO hafd.transactions VALUES (1, ...), (2, ...), ...;
INSERT INTO hafd.operations VALUES ...;
-- etc.

-- AFTER (1 line)
PERFORM test.create_irreversible_data(
    end_block => 8,
    include_transactions => TRUE,
    include_operations => TRUE
);
```

### Pattern 3: Reversible Data with Forks
```sql
-- BEFORE (30 lines per fork)
INSERT INTO hafd.blocks_reversible VALUES
    (6, ..., 1), (7, ..., 1), ...;
INSERT INTO hafd.transactions_reversible VALUES
    (6, ..., 1), (7, ..., 1), ...;
-- Repeat for each fork

-- AFTER (3 lines for 3 forks)
PERFORM test.create_reversible_data_for_fork(6, 10, 1, include_all_data => TRUE);
PERFORM test.create_reversible_data_for_fork(7, 10, 2, include_all_data => TRUE);
PERFORM test.create_reversible_data_for_fork(8, 10, 3, include_all_data => TRUE);
```

### Pattern 4: Application Loop with Mocks
```sql
-- Setup minimal data
PERFORM test.create_accounts();
PERFORM test.create_blocks(1, 50);

-- Install and use mock
PERFORM test.install_mock_hive_get_estimated_hive_head_block();
PERFORM test.set_head_block_num(50);

-- Application-specific logic
CALL hive.app_next_iteration(...);

-- Update mock
PERFORM test.set_head_block_num(100);
```

---

## Edge Cases

### Case 1: Non-Sequential Blocks
```sql
-- If test creates blocks 1, 2, 5, 10 (not sequential)
PERFORM test.create_blocks(1, 2);
INSERT INTO hafd.blocks (block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (5, ...); -- Custom
INSERT INTO hafd.blocks (block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (10, ...); -- Custom
```

### Case 2: Different Producers per Block
```sql
-- If blocks have different producers
PERFORM test.create_blocks(1, 5, producer_id => 5);
PERFORM test.create_blocks(6, 8, producer_id => 7);
```

### Case 3: Custom Hash Patterns
```sql
-- If test relies on specific hash values in assertions
-- Keep original INSERTs or modify assertions to match test_tools pattern
-- Test tools generate hashes as: BADD<hex(block*16)>
```

### Case 4: Multiple Transactions per Block
```sql
-- Create first transaction for each block
PERFORM test.create_transactions(1, 5, trx_in_block => 0);

-- Add second transaction for specific blocks
PERFORM test.create_transactions(3, 3, trx_in_block => 1);
PERFORM test.create_transactions(4, 4, trx_in_block => 1);
```

---

## Testing Your Refactoring

### Validation Checklist

1. **Run the refactored test**
   ```bash
   # Run single test
   ctest -R test.functional.hive_fork_manager.hived_api.copy_blocks_to_irreversible -V
   ```

2. **Verify test passes**
   - [ ] Test completes successfully
   - [ ] All assertions pass
   - [ ] No unexpected warnings

3. **Compare data created**
   ```sql
   -- Add temporary debugging to both versions:
   SELECT COUNT(*) FROM hafd.blocks;
   SELECT COUNT(*) FROM hafd.blocks_reversible;
   SELECT COUNT(*) FROM hafd.accounts;
   -- etc.
   ```

4. **Check execution time**
   - Refactored tests should have similar or better execution time
   - If slower, review function usage (may be creating unnecessary data)

### Common Issues

#### Issue: Assertion failures on exact values
**Cause**: test_tools generates hashes/data differently than manual INSERTs
**Solution**:
- Option 1: Update assertions to match test_tools format
- Option 2: Keep original INSERT for data that assertions check exactly

#### Issue: Missing data
**Cause**: Forgot to enable a flag or create specific data type
**Solution**: Review function parameters, ensure all needed data types are created

#### Issue: Wrong block ranges
**Cause**: Mismatched start/end blocks between original and refactored
**Solution**: Carefully review original INSERT ranges

---

## Example Walkthroughs

### Walkthrough 1: copy_blocks_to_irreversible.sql

**Original (78 lines):**
```sql
CREATE OR REPLACE PROCEDURE haf_admin_test_given() AS $BODY$
BEGIN
    INSERT INTO hafd.fork(id, block_num, time_of_fork)
    VALUES (2, 6, '2020-06-22 19:10:25-07'::timestamp),
           (3, 7, '2020-06-22 19:10:25-07'::timestamp);

    INSERT INTO hafd.blocks (block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES
        (1, '\xBADD10', ...),
        (2, '\xBADD20', ...),
        (3, '\xBADD30', ...),
        (4, '\xBADD40', ...),
        (5, '\xBADD50', ...);

    INSERT INTO hafd.accounts(id, name, block_num)
    VALUES (5, 'initminer', 1), (6, 'alice', 1), (7, 'bob', 1);

    INSERT INTO hafd.blocks_reversible VALUES
        (4, ..., 1), (5, ..., 1), (6, ..., 1),
        (7, ..., 2), (8, ..., 2), (9, ..., 2),
        (8, ..., 3), (9, ..., 3), (10, ..., 3);
END;
$BODY$;
```

**Step-by-step refactoring:**

1. **Identify pattern**: Standard fork scenario (forks 2&3, standard accounts)
2. **Check blocks**: 5 irreversible (1-5), reversible for 3 forks
3. **Choose approach**: Use granular functions (standard scenario is close but not exact match)

**Refactored (15 lines):**
```sql
CREATE OR REPLACE PROCEDURE haf_admin_test_given() AS $BODY$
BEGIN
    PERFORM test.create_forks();
    PERFORM test.create_accounts();
    PERFORM test.create_blocks(1, 5);

    PERFORM test.create_blocks_reversible(4, 6, 1);
    PERFORM test.create_blocks_reversible(7, 9, 2);
    PERFORM test.create_blocks_reversible(8, 10, 3);
END;
$BODY$;
```

**Reduction**: 78 lines → 15 lines (81% reduction)

---

### Walkthrough 2: app_next_block_process_new_block_event.sql

**Original (81 lines):**
```sql
CREATE OR REPLACE PROCEDURE haf_admin_test_given() AS $BODY$
BEGIN
    INSERT INTO hafd.operation_types VALUES ...;
    INSERT INTO hafd.blocks (block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (1, ...);
    INSERT INTO hafd.accounts VALUES (5, 'initminer', 1);

    PERFORM hive.end_massive_sync(1);
    PERFORM hive.push_block(( 2, ... ), NULL, NULL, NULL, NULL, NULL, NULL);

    CREATE SCHEMA A;
    PERFORM hive.app_create_context(_name => 'context', _schema => 'a');
    CREATE TABLE table1(id INTEGER) INHERITS(a.context);
END;
$BODY$;
```

**Step-by-step refactoring:**

1. **Identify pattern**: Minimal blockchain + API calls + context setup
2. **What to refactor**: Only the initial data setup (operation types, blocks, accounts)
3. **What to keep**: hive API calls, context creation

**Refactored (28 lines):**
```sql
CREATE OR REPLACE PROCEDURE haf_admin_test_given() AS $BODY$
BEGIN
    -- Refactored: initial setup
    PERFORM test.create_operation_types();
    PERFORM test.create_accounts(account_names => ARRAY['initminer']);
    PERFORM test.create_blocks(1, 1);

    -- Unchanged: test-specific logic
    PERFORM hive.end_massive_sync(1);
    PERFORM hive.push_block(( 2, ... ), NULL, NULL, NULL, NULL, NULL, NULL);

    CREATE SCHEMA A;
    PERFORM hive.app_create_context(_name => 'context', _schema => 'a');
    CREATE TABLE table1(id INTEGER) INHERITS(a.context);
END;
$BODY$;
```

**Reduction**: 81 lines → 28 lines (65% reduction)
**Note**: More modest reduction because test has significant test-specific logic

---

## Best Practices

### DO:
✓ Start with high-level functions, use granular ones only when needed
✓ Keep test-specific logic unchanged
✓ Preserve all hive API calls
✓ Test immediately after refactoring
✓ Update assertions if using test_tools' standard data formats
✓ Document any deviations from standard patterns

### DON'T:
✗ Change test behavior
✗ Remove test-specific data
✗ Modify when/then procedures unless simplifying them too
✗ Skip testing after refactoring
✗ Use test_tools for tables that aren't in the library

---

## Quick Reference

| Original Code | test_tools Replacement |
|--------------|------------------------|
| `INSERT INTO hafd.operation_types` | `test.create_operation_types()` |
| `INSERT INTO hafd.fork` | `test.create_forks()` |
| `INSERT INTO hafd.accounts` | `test.create_accounts()` |
| `INSERT INTO hafd.blocks` | `test.create_blocks(start, end)` |
| `INSERT INTO hafd.blocks_reversible` | `test.create_blocks_reversible(start, end, fork_id)` |
| `INSERT INTO hafd.transactions` | `test.create_transactions(start, end)` |
| `INSERT INTO hafd.operations` | `test.create_operations(start, end)` |
| Standard complete setup | `test.setup_standard_fork_scenario()` |
| Simple blockchain | `test.setup_simple_blockchain(blocks)` |

---

## Getting Help

If you're unsure about refactoring a specific test:
1. Check if there's a similar test already refactored (look in examples_refactored/)
2. Review this guide's examples
3. Ask the team for guidance
4. Start with a conservative approach (granular functions) and optimize later

Happy refactoring!
