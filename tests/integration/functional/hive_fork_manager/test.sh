#!/bin/sh

extension_path=$1
test_path=$2;
setup_scripts_dir_path=$3;
postgres_port=$4;

evaluate_result() {
  local result=$1;

  if [ ${result} -eq 0 ]
  then
    return;
  fi

  echo "FAILED";
  exit 1;
}

sudo -nu postgres psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -a -f  ./create_db_roles.sql;

$setup_scripts_dir_path/setup_db.sh --port=$postgres_port  \
  --haf-db-admin="haf_admin"  --haf-db-name="psql_tools_test_db" --haf-app-user="alice" --haf-app-user="bob"

if [ $? -ne 0 ]
then
  echo "FAILED. Cannot setup database"
  exit 1;
fi

psql -p $postgres_port -d psql_tools_test_db -a -v ON_ERROR_STOP=on -f  ./test_tools.sql;

psql -p $postgres_port -d psql_tools_test_db -a -v ON_ERROR_STOP=on -f  ${test_path};
evaluate_result $?;

psql -p $postgres_port -d psql_tools_test_db -v ON_ERROR_STOP=on -c 'SELECT test_given()';
evaluate_result $?;
psql -p $postgres_port -d psql_tools_test_db -v ON_ERROR_STOP=on -c 'SELECT test_when()';
evaluate_result $?;
psql -p $postgres_port -d psql_tools_test_db -v ON_ERROR_STOP=on -c 'SELECT test_then()';
evaluate_result $?;

# psql -d postgres -a -f ./drop_db.sql;

echo "PASSED";
exit 0;


