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

applications_folder=$1
test_path=$2;

psql -d postgres -a -f  ./create_db.sql;

psql -d psql_tools_test_db -v ON_ERROR_STOP=on -c 'CREATE EXTENSION hive_fork_manager'
if [ $? -ne 0 ]
then
  echo "FAILED. Cannot create extension"
  exit 1;
fi

psql postgresql://hived:test@localhost/psql_tools_test_db --username=hived -a -v ON_ERROR_STOP=on -f ./data/prepare_data.sql
evaluate_result $?;

( $test_path $applications_folder )
evaluate_result $?;