#!/usr/bin/env bash
#
# Check that hive_fork_manager_update_script_generator.sh fails when it's supposed to fail
#
set -eu -o pipefail

SCRIPTPATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
SCRIPTS_DIR="$SCRIPTPATH/../../../../scripts"
UPDATE_DB_NAME=update-db-test
POSTGRES_VERSION=14

export PGUSER="haf_admin"
export PGHOST="/var/run/postgresql"
export PGDATABASE="$UPDATE_DB_NAME"

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "OPTIONS:"
    echo "  --haf_binaries_dir=NAME"
    echo "  --help                    Display this help screen and exit"
    echo
}

prepare_database() {
    "$SCRIPTS_DIR/setup_db.sh" --haf-db-name="$UPDATE_DB_NAME"
}

update_database() {
    sudo "$HAF_DIR/extensions/hive_fork_manager/hive_fork_manager_update_script_generator.sh" --haf-db-name="$UPDATE_DB_NAME"
}

failswith() {(
    # body runs inside subshell to disable set -e locally
    set +e
    expected_exit_code="$1"
    shift
    "$@"
    actual_exit_code="$?"
    if [ "$actual_exit_code" -ne "$expected_exit_code" ]; then
        echo "TEST FAILED: expected to exit with $expected_exit_code, but exited with $actual_exit_code"
        return 2
    fi
)}

exec_sql() {
    sudo -Enu "$PGUSER" psql -w -d "$UPDATE_DB_NAME" -v ON_ERROR_STOP=on -q -t -A -c "$1"
}

HAF_DIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --haf_binaries_dir=*)
            HAF_DIR="${1#*=}"
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
            exit 1
            ;;
    esac
    shift
done

if [ "$HAF_DIR" = "" ]; then
    echo "ERROR: --haf_binaries_dir is required option"
    exit 1
fi

printf "\nTEST: Trying to upgrade from current database. It should pass, as nothing needs to be done.\n"
prepare_database
update_database

printf "\nTEST: Creating table referencing hive.operation. This is allowed and should succeed.\n"
prepare_database
exec_sql "create table good_table(id int, op hive.operation)"
update_database

printf "\nTEST: Creating table referencing disallowed HAF type. Upgrade should fail.\n"
prepare_database
exec_sql "create table bad_table(id int, comment hive.comment_operation)"
failswith 4 update_database

printf "\nTEST: Creating table referencing disallowed HAF domain. Upgrade should fail.\n"
prepare_database
exec_sql "create table bad_table(id int, account hive.account_name_type)"
failswith 4 update_database

printf "\nTEST: Creating table referencing allowed HAF domain. Upgrade should pass.\n"
prepare_database
exec_sql "create table good_table(id int, amount hive.hive_amount)"
update_database

printf "\nTEST: Check that function defined in hive namespace that doesn't reference current commit hash fails the upgrade.\n"
prepare_database
exec_sql "CREATE FUNCTION hive.bad_function() RETURNS VOID VOLATILE AS '/lib/postgresql/${POSTGRES_VERSION}/lib/tablefunc.so', 'crosstab' language c;"
failswith 3 update_database

echo "Succeeded"
