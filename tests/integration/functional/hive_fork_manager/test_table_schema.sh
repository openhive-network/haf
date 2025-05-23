#! /bin/bash

set -euo pipefail

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
    echo "Allows to specify required directories to run CI test"
    echo "OPTIONS:"
    echo "  --setup_scripts_path=NAME     "
    echo "  --haf_binaries_dir=NAME     "
    echo "  --ci_project_dir=NAME     "
    echo "  --build_root_dir=NAME     "
    echo "  --pattern_dir=NAME     "
    echo "  --db-admin=NAME "
    echo "  --db-name=NAME "
    echo "  --host=POSTGRES_HOST "
    echo "  --port=POSTGRES_PORT "
    echo "  --help                    Display this help screen and exit"
    echo
}

SETUP_DIR=""
HAF_DIR=""
DIR=""

DB_ADMIN="haf_admin"
DB_NAME="haf_block_log"
POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432

while [ $# -gt 0 ]; do
  case "$1" in
    --setup_scripts_path=*)
        SETUP_DIR="${1#*=}"
        ;;
    --haf_binaries_dir=*)
        HAF_DIR="${1#*=}"
        ;;
    --ci_project_dir=*)
        DIR="${1#*=}"
        ;;
    --build_root_dir=*)
        HIVE_BUILD_ROOT_PATH="${1#*=}"
        ;;
    --pattern_dir=*)
        PATTERNS_PATH="${1#*=}"
        ;;
    --db-admin=*)
        DB_ADMIN="${1#*=}"
        ;;
    --db-name=*)
        DB_NAME="${1#*=}"
        ;;
    --host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --port=*)
        POSTGRES_PORT="${1#*=}"
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

test_extension_update() {
    # add new column to accounts table
    echo
    echo "Making a change in table schema by adding column in accounts table"

    sudo -Enu "$DB_ADMIN" psql -w $POSTGRES_ACCESS -d "$DB_NAME" -v ON_ERROR_STOP=on -U "$DB_ADMIN" -c "ALTER TABLE hafd.accounts ADD COLUMN phone_number VARCHAR;"
    # run generator script
    POSTGRES_VERSION=17
    sudo /usr/share/postgresql/${POSTGRES_VERSION}/extension/hive_fork_manager_update_script_generator.sh 2>&1 | tee -i update.txt || true
    # back to old format of db
    sudo -Enu "$DB_ADMIN" psql -w $POSTGRES_ACCESS -d "$DB_NAME" -v ON_ERROR_STOP=on -U "$DB_ADMIN" -c "ALTER TABLE hafd.accounts DROP COLUMN phone_number;"
    # test
    if grep -q "Table schema is inconsistent" update.txt; then
        echo "Update test succeed (changed account table)"
    else
        echo "Update test failed (changed account table)"
        exit 1
    fi
}

test_extension_update
