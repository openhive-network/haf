#!/bin/sh

evaluate_result() {
  local result=$1;

  if [ ${result} -eq 0 ]
  then
    return;
  fi

  echo "FAILED";
  exit 1;
}

extension_path=$1
test_path=$2;

psql -d postgres -a -f  ./create_db.sql;

psql -d psql_tools_test_db -v ON_ERROR_STOP=on -c 'CREATE EXTENSION hive_fork_manager CASCADE;'
if [ $? -ne 0 ]
then
  echo "FAILED. Cannot create extension"
  exit 1;
fi

# add test functions:
# load tests function
psql -d psql_tools_test_db -a -v ON_ERROR_STOP=on -f  ${test_path};

# GIVEN
psql postgresql://hived:test@localhost/psql_tools_test_db --username=hived -a -v ON_ERROR_STOP=on -c 'SELECT hived_test_given()';
evaluate_result $?;
psql postgresql://alice:test@localhost/psql_tools_test_db --username=alice -a -v ON_ERROR_STOP=on -c 'SELECT alice_test_given()';
evaluate_result $?;
psql postgresql://bob:test@localhost/psql_tools_test_db --username=bob -a -v ON_ERROR_STOP=on -c 'SELECT bob_test_given()';
evaluate_result $?;

# WHEN
psql postgresql://hived:test@localhost/psql_tools_test_db --username=hived -a -v ON_ERROR_STOP=on -c 'SELECT hived_test_when()';
evaluate_result $?;
psql postgresql://alice:test@localhost/psql_tools_test_db --username=alice -a -v ON_ERROR_STOP=on -c 'SELECT alice_test_when()';
evaluate_result $?;
psql postgresql://bob:test@localhost/psql_tools_test_db --username=bob -a -v ON_ERROR_STOP=on -c 'SELECT bob_test_when()';
evaluate_result $?;

# THEN
psql postgresql://hived:test@localhost/psql_tools_test_db --username=hived -a -v ON_ERROR_STOP=on -c 'SELECT hived_test_then()';
evaluate_result $?;
psql postgresql://alice:test@localhost/psql_tools_test_db --username=alice -a -v ON_ERROR_STOP=on -c 'SELECT alice_test_then()';
evaluate_result $?;
psql postgresql://bob:test@localhost/psql_tools_test_db --username=bob -a -v ON_ERROR_STOP=on -c 'SELECT bob_test_then()';
evaluate_result $?;

echo "PASSED";
exit 0;

