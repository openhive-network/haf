#!/bin/sh

extension_path=$1
test_path=$2;

evaluate_result() {
  local result=$1;

  if [ ${result} -eq 0 ]
  then
    return;
  fi

  echo "FAILED";
  exit 1;
}

psql -d postgres -a -f  ./create_db.sql;

psql -d psql_tools_test_db -v ON_ERROR_STOP=on -c 'CREATE EXTENSION hive_fork_manager CASCADE;'
if [ $? -ne 0 ]
then
  echo "FAILED. Cannot create extension"
  exit 1;
fi

psql -d psql_tools_test_db -a -v ON_ERROR_STOP=on -f  ${test_path};
evaluate_result $?;

psql -d psql_tools_test_db -v ON_ERROR_STOP=on -c 'SELECT test_given()';
evaluate_result $?;
psql -d psql_tools_test_db -v ON_ERROR_STOP=on -c 'SELECT test_when()';
evaluate_result $?;
psql -d psql_tools_test_db -v ON_ERROR_STOP=on -c 'SELECT test_then()';
evaluate_result $?;

# psql -d postgres -a -f ./drop_db.sql;

echo "PASSED";
exit 0;


