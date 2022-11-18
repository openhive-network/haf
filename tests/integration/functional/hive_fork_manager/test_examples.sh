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

examples_folder=$1
test_path=$2;
setup_scripts_dir_path=$3;
postgres_port=$4;

sudo -nu postgres psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -a -f  ./create_db_roles.sql;

$setup_scripts_dir_path/setup_db.sh --port=$postgres_port  \
  --haf-db-admin="haf_admin" --haf-db-name="psql_tools_test_db" --haf-app-user="alice" --haf-app-user="bob"

if [ $? -ne 0 ]
then
  echo "FAILED. Cannot create extension"
  exit 1;
fi

psql -p $postgres_port -d psql_tools_test_db -a -v ON_ERROR_STOP=on -f  ./test_tools.sql;

psql postgresql://test_hived:test@localhost:$postgres_port/psql_tools_test_db --username=test_hived -a -v ON_ERROR_STOP=on -f ./examples/prepare_data.sql
evaluate_result $?;

python3.8 -m venv .test_examples
. ./.test_examples/bin/activate

python3 -mpip install --upgrade pip

python3 -mpip install \
  pexpect==4.8 \
  psycopg2==2.9.3 \
  sqlalchemy==1.4.18 \
  jinja2==2.10

( $test_path $examples_folder $postgres_port)

evaluate_result $?;

