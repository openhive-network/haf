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

uuid_gen() {
  cat /proc/sys/kernel/random/uuid | od -A n -t x1 -N 16 | tr -dc '[:xdigit:]'
}

setup_test_database() {
  setup_scripts_dir_path=$1;
  postgres_port="$2"

  UUID=`uuid_gen`
  DB_NAME="psql_tools_test_db_$UUID"

  sudo -nu postgres psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -a -f  ./create_db_roles.sql;

  "$setup_scripts_dir_path/setup_db.sh" --port="$postgres_port"  \
    --haf-db-admin="haf_admin"  --haf-db-name="$DB_NAME" --haf-app-user="alice" --haf-app-user="bob"

  if [ $? -ne 0 ]
  then
    echo "FAILED. Cannot setup database"
    exit 1;
  fi
}
