#!/usr/bin/env bash

on_exit() {
  psql -p "$postgres_port" -d "$DB_NAME" -v ON_ERROR_STOP=on -f ./tools/cleanup.sql;
  echo "On exit $?"
}

evaluate_result() {
  local result=$1;

  if [ "${result}" -eq 0 ]
  then
    return;
  fi

  echo "FAILED with result ${result}";
  exit 1;
}

evaluate_error_result() {
  local result=$1;

  if [ "${result}" -ne 0 ]
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
  extension_path="$4"

  test_directory=$(dirname "${test_path}");
  sql_setup_fixture="./${test_directory}/fixture.sql";

  test_name=$(test_name_from_path "$test_path")
  test_name_crc="$(echo "${test_name}" | cksum | sed 's/ /_/')"

  DB_NAME="t_${test_name_crc}_${test_name}"
  DB_NAME="${DB_NAME:0:63}" # Postgres database name has hard limit of 63 chars

  sudo -nu postgres psql -p "$postgres_port" -d postgres -v ON_ERROR_STOP=on -a -f ./tools/create_db_roles.sql

  "${setup_scripts_dir_path}/setup_db.sh" --port="$postgres_port"  \
    --haf-db-admin="haf_admin"  --haf-db-name="$DB_NAME" --haf-app-user="alice" --haf-app-user="bob"
  if [ $? -ne 0 ]; then
    echo "FAILED. Cannot setup database"
    exit 1
  fi

  # ATTENTION: normally the extension does not contain hash functions
  # so the db is little different than production state, but these are functional tests so IMO it is acceptable
  psql -p "${postgres_port}" -d "${DB_NAME}" -a -v ON_ERROR_STOP=on -f "${extension_path}/update.sql"

  # TODO(mickiewicz@syncad.com): remove when releasing on pg16 where 'public' schema is not accessible by default
  if ! psql -p "${postgres_port}" -d "${DB_NAME}" -a -v ON_ERROR_STOP=on -c "REVOKE CREATE ON SCHEMA public FROM PUBLIC;";
  then
    echo "FAILED. Cannot revoke CREATE from public schema"
    exit 1;
  fi



  if [ -e "${sql_setup_fixture}" ]; then
    echo "psql -p $postgres_port -d $DB_NAME -a -v ON_ERROR_STOP=on -f"
    if ! psql -p "${postgres_port}" -d "${DB_NAME}" -a -v ON_ERROR_STOP=on -f "${sql_setup_fixture}";
    then
        echo "FAILED. Cannot run fixture ${sql_setup_fixture}"
        exit 1
    fi
  fi

}
