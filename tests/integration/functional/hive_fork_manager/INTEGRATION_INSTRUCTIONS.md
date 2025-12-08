# Integration Instructions for test_tools.sql

## Overview

This document explains how to integrate test_tools.sql into the HAF test framework so it's available for all functional tests.

## Integration Steps

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

Or use absolute path:
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

## Verification After Integration

### Test 1: Check Functions Exist

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

### Test 2: Run a Simple Test

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

### Test 3: Run Existing Test Suite

```bash
# Run one test to verify integration
ctest -R test.functional.hive_fork_manager.hived_api.schema_test -V

# If successful, run full suite
ctest -R test.functional.hive_fork_manager -j4
```

## Common Integration Issues

### Issue 1: "schema 'test' does not exist"

**Cause:** test_tools.sql not loaded or loaded after test execution started

**Solution:**
- Ensure test_tools.sql is loaded in setup phase
- Check load order in setup script
- Verify file path is correct

### Issue 2: "function test.xxx() does not exist"

**Cause:** test_tools.sql not accessible or not loaded

**Solution:**
```sql
-- Check if test schema exists
SELECT * FROM pg_namespace WHERE nspname = 'test';

-- Check if functions are loaded
SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'test';
```

### Issue 3: "permission denied for schema test"

**Cause:** Test user doesn't have access to test schema

**Solution:**
```sql
-- Grant access to test schema
GRANT USAGE ON SCHEMA test TO test_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test TO test_user;
```

### Issue 4: Tests fail with "table hafd.xxx does not exist"

**Cause:** Test functions being called before HAF schema is initialized

**Solution:**
- Ensure HAF extension is created first
- Load test_tools.sql after HAF initialization
- Check setup script order

## Test Framework Modifications

### For pytest-based Tests

If using pytest (like the Python examples):

```python
# In conftest.py or test setup
import psycopg2

@pytest.fixture(scope="session")
def load_test_tools(db_connection):
    """Load test_tools.sql before all tests"""
    test_tools_path = Path(__file__).parent / "test_tools.sql"
    with open(test_tools_path) as f:
        db_connection.execute(f.read())
    db_connection.commit()

# Use in tests
def test_something(db_connection, load_test_tools):
    db_connection.execute("SELECT test.setup_simple_blockchain(5)")
    # ... rest of test
```

### For Shell Script Tests

If tests are run via shell scripts:

```bash
#!/bin/bash
# In test_examples.sh or similar

# Load test utilities first
psql -U $DB_USER -d $DB_NAME -f "tests/integration/functional/hive_fork_manager/test_tools.sql"

# Then run test
psql -U $DB_USER -d $DB_NAME -f "$TEST_FILE"
```

## Performance Considerations

### Loading Time

test_tools.sql contains ~40 functions. Loading time is typically:
- **Initial load:** < 100ms
- **Cached:** < 10ms

This is negligible compared to test execution time.

### Memory Usage

Functions are compiled and cached by PostgreSQL:
- **Per function:** ~10-50KB
- **Total for all functions:** < 2MB

No significant memory impact.

### Execution Overhead

Function calls have minimal overhead:
- **Simple function (create_accounts):** < 1ms
- **Complex function (setup_standard_fork_scenario):** 10-50ms

This is typically **faster** than individual INSERT statements due to:
- Reduced parsing overhead
- Batch operations
- Optimized patterns

## Rollback and Uninstallation

If you need to remove test_tools:

```sql
-- Remove all test functions
DROP SCHEMA test CASCADE;

-- Recreate empty test schema (if needed for other utilities)
CREATE SCHEMA test;
```

For gradual rollback during testing:
```sql
-- Disable specific functions
DROP FUNCTION test.setup_standard_fork_scenario();

-- Tests using this function will fail, others continue working
```

## Best Practices

### 1. Load Once Per Test Session
```sql
-- Good: Load in setup
\i test_tools.sql
-- Run many tests

-- Bad: Load in each test
-- Each test file: \i test_tools.sql (wasteful)
```

### 2. Keep test_tools.sql Under Version Control
```bash
git add tests/integration/functional/hive_fork_manager/test_tools.sql
git commit -m "Add test utilities library"
```

### 3. Document in Test README
Update your test documentation to mention test_tools availability:

```markdown
## Writing Tests

All tests have access to test utility functions in the `test` schema.
See TEST_TOOLS_README.md for available functions.

Example:
```sql
PERFORM test.setup_standard_fork_scenario();
```
```

### 4. Handle Updates
When test_tools.sql is updated:

```bash
# Option A: Reload in active session
\i test_tools.sql  # PostgreSQL recompiles functions

# Option B: Restart test session
# Exit and reconnect to database
```

## Integration Checklist

Use this checklist when integrating test_tools.sql:

- [ ] Identified test setup mechanism (script/CMake/other)
- [ ] Added test_tools.sql loading to setup
- [ ] Verified load order (after HAF, before tests)
- [ ] Tested with one simple test
- [ ] Ran full test suite
- [ ] All tests pass
- [ ] Documented integration in project README
- [ ] Committed changes to version control
- [ ] Informed team about availability

## Example Integration for HAF

### Complete Setup Script Example

```sql
-- File: setup_test_db.sql
-- Purpose: Initialize test database with HAF and test utilities

-- 1. Create database and extensions
CREATE EXTENSION IF NOT EXISTS hive_fork_manager;

-- 2. Initialize HAF (if needed for your tests)
-- PERFORM hive.init_haf_db();

-- 3. Load test utilities
\i /home/dev/src/haf/tests/integration/functional/hive_fork_manager/test_tools.sql

-- 4. Verify setup
DO $$
BEGIN
    -- Check test schema exists
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'test') THEN
        RAISE EXCEPTION 'test schema not found - test_tools.sql not loaded correctly';
    END IF;

    -- Check functions available
    IF (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'test') < 10 THEN
        RAISE EXCEPTION 'test functions not loaded - check test_tools.sql path';
    END IF;

    RAISE NOTICE 'Test utilities loaded successfully';
END $$;
```

### Example Test Using Integrated test_tools

```sql
-- File: hived_api/my_new_test.sql
-- No need to load test_tools.sql - it's already available!

CREATE OR REPLACE PROCEDURE haf_admin_test_given() AS $BODY$
BEGIN
    -- Just use the functions directly
    PERFORM test.setup_standard_fork_scenario();
END;
$BODY$;

-- Rest of test...
```

## Troubleshooting Commands

```sql
-- Check if test_tools is loaded
SELECT COUNT(*) as num_test_functions
FROM information_schema.routines
WHERE routine_schema = 'test';

-- List all test functions
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'test'
ORDER BY routine_name;

-- Check test schema permissions
SELECT nspname, nspowner,
       has_schema_privilege(current_user, nspname, 'USAGE') as can_use
FROM pg_namespace
WHERE nspname = 'test';

-- Test a simple function
SELECT test.create_operation_types();
SELECT * FROM hafd.operation_types;
```

## Support

If you encounter issues during integration:
1. Check this document's troubleshooting section
2. Verify file paths and permissions
3. Review PostgreSQL logs for errors
4. Test with a minimal example first
5. Contact the team for assistance

---

**Last Updated:** 2025-12-08
**Version:** 1.0
