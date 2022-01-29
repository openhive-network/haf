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
setup_scripts_dir_path=$3;
postgres_port=$4;

sudo -nu postgres psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -a -f  ./create_db_roles.sql;

$setup_scripts_dir_path/setup_db.sh --port=$postgres_port  \
  --haf-db-admin="haf_admin" --haf-db-name="psql_tools_test_db" --haf-db-owner="alice" --haf-db-owner="bob"

if [ $? -ne 0 ]
then
  echo "FAILED. Cannot create extension"
  exit 1;
fi

# add test functions:
# load tests function
psql -p $postgres_port -d psql_tools_test_db -a -v ON_ERROR_STOP=on -f  ${test_path};

# GIVEN
psql postgresql://test_hived:test@localhost:$postgres_port/psql_tools_test_db --username=test_hived -a -v ON_ERROR_STOP=on -c 'SELECT hived_test_given()';
evaluate_result $?;
psql postgresql://alice:test@localhost:$postgres_port/psql_tools_test_db --username=alice -a -v ON_ERROR_STOP=on -c 'SELECT alice_test_given()';
evaluate_result $?;
psql postgresql://bob:test@localhost:$postgres_port/psql_tools_test_db --username=bob -a -v ON_ERROR_STOP=on -c 'SELECT bob_test_given()';
evaluate_result $?;

# WHEN
psql postgresql://test_hived:test@localhost:$postgres_port/psql_tools_test_db --username=test_hived -a -v ON_ERROR_STOP=on -c 'SELECT hived_test_when()';
evaluate_result $?;
psql postgresql://alice:test@localhost:$postgres_port/psql_tools_test_db --username=alice -a -v ON_ERROR_STOP=on -c 'SELECT alice_test_when()';
evaluate_result $?;
psql postgresql://bob:test@localhost:$postgres_port/psql_tools_test_db --username=bob -a -v ON_ERROR_STOP=on -c 'SELECT bob_test_when()';
evaluate_result $?;

# THEN
psql postgresql://test_hived:test@localhost:$postgres_port/psql_tools_test_db --username=test_hived -a -v ON_ERROR_STOP=on -c 'SELECT hived_test_then()';
evaluate_result $?;
psql postgresql://alice:test@localhost:$postgres_port/psql_tools_test_db --username=alice -a -v ON_ERROR_STOP=on -c 'SELECT alice_test_then()';
evaluate_result $?;
psql postgresql://bob:test@localhost:$postgres_port/psql_tools_test_db --username=bob -a -v ON_ERROR_STOP=on -c 'SELECT bob_test_then()';
evaluate_result $?;

echo "PASSED";
exit 0;

