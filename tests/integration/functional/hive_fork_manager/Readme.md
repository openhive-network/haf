## EXAMPLES

The `hive_fork_manager` test introduces a new type of test that checks if examples
from the `src/hive_fork_manager/doc/examples` folder work correctly.
The CMake macro `ADD_EXAMPLES_FUNCTIONAL_TESTS(<relative_path_to_script>)` adds a test that calls [test_examples.sh](test_examples.sh) to perform the following operations:

1. Prepares the database for the application - block data and events queue with [./examples/prepare_data.sql](./examples/prepare_data.sql).
2. Executes the test script with passing it a directory with the examples.


### Python Dependencies
For tests that check application examples, Python 3 is required with the following modules installed:

- `pexpect`
- `psycopg2`
- `sqlalchemy`