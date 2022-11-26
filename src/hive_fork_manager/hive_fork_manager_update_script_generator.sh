#! /bin/bash

set -euo pipefail 

PSQL_URL="postgresql://haf_admin@localhost:5432/haf_block_log"

log_exec_params() {
  echo
  echo -n "$0 parameters: "
  for arg in "$@"; do echo -n "$arg "; done
  echo
}

log_exec_params "$@"


print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Creates a patch script that allows to upgrade existing database holding HAF data to a new version without dropping it."
    echo "OPTIONS:"
    echo "  --host=VALUE         Allows to specify a PostgreSQL host location (defaults to /var/run/postgresql)"
    echo "  --port=NUMBER        Allows to specify a PostgreSQL operating port (defaults to 5432)"
    echo "  --haf-db-name=NAME   Allows to specify a name of database to store a HAF data"
    echo "  --haf-admin-account=NAME  Allows to specify a name of database admin role having permission to create the database"
    echo "                       and install an exension inside."
    echo "                       Role MUST be earlier created on pointed Postgres instance !!!"
    echo "                       If omitted, defaults to haf_admin role."
    echo
    echo "  --help               Display this help screen and exit"
    echo
}

DB_NAME="haf_block_log"
DB_ADMIN="haf_admin"
HAF_TABLESPACE_NAME="haf_tablespace"

DEFAULT_DB_USERS=("haf_app_admin")
POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432


while [ $# -gt 0 ]; do
  case "$1" in
    --host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --port=*)
        POSTGRES_PORT="${1#*=}"
        ;;
    --haf-db-name=*)
        DB_NAME="${1#*=}"
        ;;
    --haf-admin-account=*)
        DB_ADMIN="${1#*=}"
        ;;

    --help)
        print_help
        exit 0
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option"
        echo
        print_help
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument"
        echo
        print_help
        exit 2
        ;;
    esac
    shift
done

POSTGRES_ACCESS="--host $POSTGRES_HOST --port $POSTGRES_PORT"

COMMIT_PREV_ID=''
COMMIT_NEW_ID='@HAF_GIT_REVISION_SHA@'

POSTGRES_EXTENSION_DIR='@POSTGRES_SHAREDIR@/extension'

get_deployed_version() {
  echo "Attempting to find version of already deployed hive_fork_manager extension..."

  COMMIT_PREV_ID=$(sudo -Enu "$DB_ADMIN" psql -w $POSTGRES_ACCESS -d "$DB_NAME" -v ON_ERROR_STOP=on -U "$DB_ADMIN" -t -A -c "SELECT extversion FROM pg_extension WHERE extname = 'hive_fork_manager'")

  echo "Already deployed hive_fork_manager has a version: $COMMIT_PREV_ID"
}

generate_final_update_script() {
  echo
  echo "Attempting to generate update file..."
  pushd "${POSTGRES_EXTENSION_DIR}"

  # Postgres extension update rules require to be done only in incremental way by pointing a script hive_fork_manager--<from>--<to>.sql
  ln -svf "${POSTGRES_EXTENSION_DIR}/hive_fork_manager_update--$COMMIT_NEW_ID.sql" "hive_fork_manager--$COMMIT_PREV_ID--$COMMIT_NEW_ID.sql"

  popd
  echo "Update file was created correctly"
}

make_update() {
  echo
  echo "Attempting to update your database..."

  psql "$PSQL_URL" -v ON_ERROR_STOP=on -c "ALTER EXTENSION hive_fork_manager UPDATE"
}

get_deployed_version

generate_final_update_script

make_update


