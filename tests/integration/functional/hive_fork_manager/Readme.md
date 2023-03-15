# Hive Fork Manager functional tests
The tests start scripts which checks hive_fork_manager extension functionalities.
Every test is started on empty database named `psql_tools_test_db`. The database is prepared before each test with script [create_db.sql](./create_db.sql).
Moreover three roles are created 'hived' (inherits 'hived_group') , 'alice' and 'bob' (inherit 'hive_applications_group').

# Requirements
The tests require to have configured locally (means on local host) postgres server with the current system user as postgres SUPERUSER with CREATEDB option
  and authentication method peer(setting inside `pg_hba.conf`)

For tests which check the applications examples python3 is required with modules:  pexpect, psycopg2, sqlalchemy

# Types of functional test

## SQL_FUNCTIONAL
The tests are runned with SUPERUSER privileges - it means they test functionalities without checking authorization contraints.
SQL_FUNCTIONAL confirms that logic of the extension works corectly. The tests were written before authorization was introduced to 'hive_fork_manager'.
The tests are added with the macro `ADD_SQL_FUNCTIONAL_TESTS( <relative_path_to_sql_script> )`. Each test case is a separated sql script and contains
three functions:
1. __test_given__ setup state before execution functionality uder test
2. __test_when__ executes functionality under test
3. __test_then__ validate results of executed functionality

The functions above are called with presented order.

## AUTHORIZATION
The tests check authorization constraints - if application and hived cannot modifie private data of separated roles. Three roles
participate in each tests: 'hived' - which represents hived process, 'alice' and 'bob' which represents two separated applications.
Each test script has to define set of three function per each role <role_name>_given, <role_name>_when, <role_name>_then. The functions
are runned one by one in the order:
1. hived_given
1. alice_given
1. bob_given
2. hived_when
2. alice_when
2. bob_when
1. hived_then
1. alice_then
1. bob_then

Function which name started with a role name is called with this role's privilleges. For example 'hived_given' is called
by 'hived' role.

To add authorization test use cmake macro `ADD_AUTHORIZATION_FUNCTIONAL_TESTS( <sql_script_relative_local_path> )`.
The macro add call [test_authorization.sh](../tools/test_authorization.sh) with passing given script to run.

## EXAMPLES
The tests check if examples from folder 'src/hive_fork_manager/doc/examples' work correctly. The macro `ADD_EXAMPLES_FUNCTIONAL_TESTS( <relative_path_to_script> )`
adds test which calls [test_examples.sh]( test_examples.sh ) to do operations in order:
1. prepares database for application - blocks data and events queue with [./examples/prepare_data.sql](./examples/prepare_data.sql) 
2. executes the test script with passing it a directory with the examples
