## SQL Functional Tests

The SQL Functional Tests use a GIVEN -> WHEN -> THEN pattern to verify the behavior
of a function under test, with SQL queries executed on a PostgreSQL server.
The tests are divided into subdirectories for different modules, and each test script creates a separate database for testing.

### Directories
- `tools`: Contains scripts to set up a test database and run tests. The scripts use functions from the [scripts](..%2F..%2F..%2Fscripts) folder.
- `hive_fork_manager`: Tests for the `hive_fork_manager` module.
- `query_supervisor`: Tests for the `query_supervisor` module.

### PostgreSQL Setup
Before running the tests, ensure that you have a PostgreSQL server configured locally.
The server should have the following roles:

- `haf_admin`: A superuser
- `test_hived`: Inherits 'hived_group' from 'hive_fork_manager' 
- `alice`: Inherits 'hive_applications_group' from 'hive_fork_manager' 
- `bob`: Inherits 'hive_applications_group' from 'hive_fork_manager' 

### Test Database Setup
Each test script creates a separate database for testing, with the name generated automatically
based on the test script file name. The database is set up with the `hive_fork_manager` extension loaded.
The database is created before the test code is executed and dropped after the test finishes and passes.
If a test fails, the database remains for further debugging.

### Test format
Each test is written in the GIVEN -> WHEN -> THEN format, with an additional error function.
The `ADD_SQL_FUNCTIONAL_TEST` CMake macro is used to add a test, with the test script file path as a parameter.

#### Error function
The error function is used when a test case expects an error that cannot be detected within the SQL code.
In this case, the test engine detects an error by evaluating the result returned by `psql`,
a PostgreSQL command-line client. A test case fails when an error function ends without error.

#### Test functions and its execution
For each role presented above, the author of the test can write `given`/`when`/`error`/`then` SQL functions.
The names of the functions must have the format '`<role_name>_test(given|when|error|then)`'.
The test engine executes the functions in the following order:
- `haf_admin_test_given`, `test_hived_test_given`, `alice_given`, `bob_given`
- `haf_admin_test_when`, `test_hived_test_when`, `alice_test_when`, `bob_test_when`
- `haf_admin_test_error`, `test_hived_test_error`, `alice_test_error`, `bob_test_error`
- `haf_admin_test_then`, `test_hived_test_then`, `alice_test_then`, `bob_test_then`

#### Optionality
The author of the test can omit any of the functions presented above.
The test engine does not treat a lack of a function as an error and will simply not try to execute it if it does not exist.

#### Test Grouping and Fixtures
Tests are organized into folders, and if a folder contains a file named fixture.sql,
it will be executed by the psql command-line client immediately after setting up the database for each of test in a group.
Fixtures are useful for configuring common settings or data for a group of tests.

### Authorization
Functions are called by the same role which name starts the function name, 
which allows for testing interactions between roles and accessing a variety of database elements.


