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

prepare_sql_script() {
    version="$1"
    # remove any existing sql script with given version
    sudo rm -f "/usr/share/postgresql/$POSTGRES_VERSION/extension/hive_fork_manager--$version.sql"
    # copy the newest hive_fork_manager--\*.sql script as hive_fork_manager--${version}.sql
    (cd "/usr/share/postgresql/$POSTGRES_VERSION/extension/" && \
        sudo cp "$(find ./ -maxdepth 1 -iname hive_fork_manager--\*.sql -type f -printf '%T@ %p\n' | sort -nr | head -1 | awk '{print $2}')" "hive_fork_manager--$version.sql")
}

prepare_database() {
    "$SCRIPTS_DIR/setup_db.sh" --haf-db-name="$UPDATE_DB_NAME" "$@"
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

check_view_exists() {(
    # body runs inside subshell to disable set -e locally
    set +e
    exec_sql "\d $1" | grep -iv 'Did not find any relation named' >/dev/null
    actual_exit_code="$?"
    if [ "$actual_exit_code" -ne "0" ]; then
        echo "TEST FAILED: view $1 expected to exist after upgrade, but doesn't"
        return 3
    fi
)}

check_view_has_comment() {(
    # body runs inside subshell to disable set -e locally
    set +e
    has_comment=$(exec_sql "SELECT obj_description('$1'::regclass, 'pg_class') IS NOT NULL")
    if [ "$has_comment" != "t" ]; then
        echo "TEST FAILED: view $1 expected to have a comment, but doesn't"
        return 3
    fi
)}

check_table_is_empty() {
    row_count=$(exec_sql "table $1" | wc -l)
    if [ "$row_count" -ne "0" ]; then
        echo "TEST FAILED: table $1 expected to be empty, but isn't"
        return 4
    fi
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

printf "\nTEST: Creating view referencing allowed types. This should pass\n"
prepare_database
exec_sql "create view good_view as select num, total_vesting_fund_hive, total_vesting_shares, current_hbd_supply, hbd_interest_rate from hive.blocks"
exec_sql "comment on view good_view is 'foo'"
update_database
check_view_exists good_view
check_view_has_comment good_view

printf "\nTEST: Creating view referencing disallowed type. This should still pass and the view should be recreated.\n"
prepare_sql_script 0000000000000000000000000000000000000000
prepare_database --version="0000000000000000000000000000000000000000"
exec_sql "create view public.bad_view as select id,body_binary::hive.comment_operation from hive.operations where op_type_id=1"
exec_sql "comment on view public.bad_view is 'foo'"
update_database
check_view_exists bad_view
check_table_is_empty hive.deps_saved_ddl
check_view_has_comment bad_view

printf "\nTEST: Creating materialized view referencing allowed types. This should pass\n"
prepare_database
exec_sql "create materialized view good_materialized_view as select num, total_vesting_fund_hive, total_vesting_shares, current_hbd_supply, hbd_interest_rate from hive.blocks"
exec_sql "comment on materialized view good_materialized_view is 'foo'"
update_database
check_view_exists good_materialized_view
check_view_has_comment good_materialized_view

printf "\nTEST: Creating materialized view referencing disallowed type. This should still pass and the view should be recreated.\n"
prepare_sql_script 0000000000000000000000000000000000000000
prepare_database --version="0000000000000000000000000000000000000000"
exec_sql "create materialized view public.bad_materialized_view as select id,body_binary::hive.comment_operation from hive.operations where op_type_id=1"
exec_sql "comment on materialized view public.bad_materialized_view is 'foo'"
update_database
check_view_exists bad_materialized_view
check_table_is_empty hive.deps_saved_ddl
check_view_has_comment bad_materialized_view

printf "\nTEST: Check that function defined in hive namespace that doesn't reference current commit hash fails the upgrade.\n"
prepare_database
exec_sql "CREATE FUNCTION hive.bad_function() RETURNS VOID VOLATILE AS '/lib/postgresql/${POSTGRES_VERSION}/lib/tablefunc.so', 'crosstab' language c;"
failswith 3 update_database

echo "Succeeded"
