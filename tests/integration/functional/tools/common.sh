#!/bin/sh

evaluate_result() {
  local result=$1;

  if [ ${result} -eq 0 ]
  then
    return;
  fi

  echo "FAILED with result ${result}";
  exit 1;
}

evaluate_error_result() {
  local result=$1;

  if [ ${result} -ne 0 ]
  then
    return;
  fi

  echo "FAILED with result ${result}. Error was expected.";
  exit 1;
}

test_name_from_path() {
  # Convert test path to name, e.g. 'a/b/c.sql' => 'a_b_c'
  test_path="$1"
  echo -n "$test_path" | sed -E -e 's#/#_#g' -e 's#.[^.]+$##'
}

setup_test_database() {
  setup_scripts_dir_path="$1"
  postgres_port="$2"
  test_path="$3"
  preload_libraries="$4";

  test_name=$(test_name_from_path "$test_path")

  DB_NAME="t_$test_name"

  sudo -nu postgres psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -a -f ./tools/create_db_roles.sql

  "$setup_scripts_dir_path/setup_db.sh" --haf-db-admin-libs="$preload_libraries" --port="$postgres_port"  \
    --haf-db-admin="haf_admin"  --haf-db-name="$DB_NAME" --haf-app-user="alice" --haf-app-user="bob"

  if [ $? -ne 0 ]; then
    echo "FAILED. Cannot setup database"
    exit 1
  fi
}
