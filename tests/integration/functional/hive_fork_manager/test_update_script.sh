#!/usr/bin/env bash
#
# Check that hive_fork_manager_update_script_generator.sh fails when it's supposed to fail
#
set -eu -o pipefail

SCRIPTPATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
SCRIPTS_DIR="$SCRIPTPATH/../../../../scripts"
UPDATE_DB_NAME=update-db-test
POSTGRES_VERSION=17

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

check_relation_structure() {(
    # body runs inside subshell to disable set -e locally
    set +e
    rel="$1"
    actual=$(exec_sql "\d $rel")
    # shellcheck disable=SC2059
    expected=$(printf "$2") # printf to convert \n to actual new lines
    if [ "$expected" != "$actual" ]; then
        printf "TEST FAILED: structure of '%s' differs:\nExpected:\n%s\nActual:\n%s\n" "$rel" "$expected" "$actual"
        return 5
    fi
)}

check_relation_comment() {(
    # body runs inside subshell to disable set -e locally
    set +e
    rel="$1"
    expected="$2"
    actual=$(exec_sql "SELECT obj_description('$1'::regclass, 'pg_class')")
    if [ "$expected" != "$actual" ]; then
        echo "TEST FAILED: '$1' expected to have a comment '$expected', but actual is '$actual'"
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
exec_sql "create table public.good_table(id int, op hive.operation)"
update_database
check_relation_structure public.good_table "id|integer|||\nop|hive.operation|||"

printf "\nTEST: Creating table referencing disallowed HAF type. Upgrade should fail.\n"
prepare_database
exec_sql "create table public.bad_table(id int, comment hive.comment_operation)"
failswith 4 update_database
check_relation_structure public.bad_table "id|integer|||\ncomment|hive.comment_operation|||"

printf "\nTEST: Creating table referencing disallowed HAF domain. Upgrade should fail.\n"
prepare_database
exec_sql "create table public.bad_table(id int, account hive.account_name_type)"
failswith 4 update_database
check_relation_structure public.bad_table "id|integer|||\naccount|hive.account_name_type|||"

printf "\nTEST: Creating table referencing allowed HAF domain. Upgrade should pass.\n"
prepare_database
exec_sql "create table public.good_table(id int, amount hive.hive_amount)"
update_database
check_relation_structure public.good_table "id|integer|||\namount|hive.hive_amount|||"

printf "\nTEST: Creating view referencing allowed types. This should pass\n"
prepare_database
exec_sql "create view public.good_view as select num, total_vesting_fund_hive, total_vesting_shares, current_hbd_supply, hbd_interest_rate from hive.blocks"
exec_sql "comment on view public.good_view is 'foo'"
update_database
check_relation_structure public.good_view "num|integer|||\ntotal_vesting_fund_hive|hive.hive_amount|||\ntotal_vesting_shares|hive.vest_amount|||\ncurrent_hbd_supply|hive.hbd_amount|||\nhbd_interest_rate|hive.interest_rate|||"
check_relation_comment public.good_view foo

printf "\nTEST: Creating view referencing disallowed type. This should still pass and the view should be recreated.\n"
prepare_sql_script 0000000000000000000000000000000000000000
prepare_database --version="0000000000000000000000000000000000000000"
exec_sql "create view public.bad_type_view as select id,body_binary::hive.transfer_operation,(body_binary::hive.transfer_operation).amount from hive.operations where hive.operation_id_to_type_id(id)=1"
exec_sql "comment on view public.bad_type_view is 'foo'"
exec_sql "create view public.bad_domain_view as select id,(body_binary::hive.transfer_operation).memo from hive.operations where hive.operation_id_to_type_id(id)=1"
exec_sql "comment on view public.bad_domain_view is 'bar'"
exec_sql "create view public.bad_mixed_view as select id,(body_binary::hive.transfer_operation).amount,(body_binary::hive.transfer_operation).memo from hive.operations where hive.operation_id_to_type_id(id)=1"
exec_sql "comment on view public.bad_mixed_view is 'baz'"
update_database
check_table_is_empty hive.deps_saved_ddl
check_relation_structure public.bad_type_view "id|bigint|||\nbody_binary|hive.transfer_operation|||\namount|hive.asset|||"
check_relation_structure public.bad_domain_view "id|bigint|||\nmemo|hive.memo|||"
check_relation_structure public.bad_mixed_view "id|bigint|||\namount|hive.asset|||\nmemo|hive.memo|||"
check_relation_comment public.bad_type_view foo
check_relation_comment public.bad_domain_view bar
check_relation_comment public.bad_mixed_view baz

printf "\nTEST: Creating view referencing disallowed type with no update taking place. This should pass and the view should be recreated.\n"
prepare_database
exec_sql "create view public.bad_type_view_2 as select id,body_binary::hive.transfer_operation,(body_binary::hive.transfer_operation).amount from hive.operations where hive.operation_id_to_type_id(id)=1"
exec_sql "comment on view public.bad_type_view_2 is 'foo'"
exec_sql "create view public.bad_domain_view_2 as select id,(body_binary::hive.transfer_operation).memo from hive.operations where hive.operation_id_to_type_id(id)=1"
exec_sql "comment on view public.bad_domain_view_2 is 'bar'"
exec_sql "create view public.bad_mixed_view_2 as select id,(body_binary::hive.transfer_operation).amount,(body_binary::hive.transfer_operation).memo from hive.operations where hive.operation_id_to_type_id(id)=1"
exec_sql "comment on view public.bad_mixed_view_2 is 'baz'"
update_database
check_table_is_empty hive.deps_saved_ddl
check_relation_structure public.bad_type_view_2 "id|bigint|||\nbody_binary|hive.transfer_operation|||\namount|hive.asset|||"
check_relation_structure public.bad_domain_view_2 "id|bigint|||\nmemo|hive.memo|||"
check_relation_structure public.bad_mixed_view_2 "id|bigint|||\namount|hive.asset|||\nmemo|hive.memo|||"
check_relation_comment public.bad_type_view_2 foo
check_relation_comment public.bad_domain_view_2 bar
check_relation_comment public.bad_mixed_view_2 baz

printf "\nTEST: Creating materialized view referencing allowed types. This should pass\n"
prepare_database
exec_sql "create materialized view public.good_materialized_view as select num, total_vesting_fund_hive, total_vesting_shares, current_hbd_supply, hbd_interest_rate from hive.blocks"
exec_sql "comment on materialized view public.good_materialized_view is 'foo'"
update_database
check_relation_structure public.good_materialized_view "num|integer|||\ntotal_vesting_fund_hive|hive.hive_amount|||\ntotal_vesting_shares|hive.vest_amount|||\ncurrent_hbd_supply|hive.hbd_amount|||\nhbd_interest_rate|hive.interest_rate|||"
check_relation_comment public.good_materialized_view foo

printf "\nTEST: Creating materialized view referencing disallowed type. This should still pass and the view should be recreated.\n"
prepare_sql_script 0000000000000000000000000000000000000000
prepare_database --version="0000000000000000000000000000000000000000"
exec_sql "create materialized view public.bad_type_materialized_view as select id,body_binary::hive.transfer_operation,(body_binary::hive.transfer_operation).amount from hive.operations where hive.operation_id_to_type_id(id)=1"
exec_sql "comment on materialized view public.bad_type_materialized_view is 'foo'"
exec_sql "create materialized view public.bad_domain_materialized_view as select id,(body_binary::hive.transfer_operation).memo from hive.operations where hive.operation_id_to_type_id(id)=1"
exec_sql "comment on materialized view public.bad_domain_materialized_view is 'bar'"
exec_sql "create materialized view public.bad_mixed_materialized_view as select id,(body_binary::hive.transfer_operation).amount,(body_binary::hive.transfer_operation).memo from hive.operations where hive.operation_id_to_type_id(id)=1"
exec_sql "comment on materialized view public.bad_mixed_materialized_view is 'baz'"
update_database
check_table_is_empty hive.deps_saved_ddl
check_relation_structure public.bad_type_materialized_view "id|bigint|||\nbody_binary|hive.transfer_operation|||\namount|hive.asset|||"
check_relation_structure public.bad_domain_materialized_view "id|bigint|||\nmemo|hive.memo|||"
check_relation_structure public.bad_mixed_materialized_view "id|bigint|||\namount|hive.asset|||\nmemo|hive.memo|||"
check_relation_comment public.bad_type_materialized_view foo
check_relation_comment public.bad_domain_materialized_view bar
check_relation_comment public.bad_mixed_materialized_view baz

printf "\nTEST: Creating materialized view referencing disallowed type with no update taking place. This should pass and the view should be recreated.\n"
prepare_database
exec_sql "create materialized view public.bad_type_materialized_view_2 as select id,body_binary::hive.transfer_operation,(body_binary::hive.transfer_operation).amount from hive.operations where hive.operation_id_to_type_id(id)=1"
exec_sql "comment on materialized view public.bad_type_materialized_view_2 is 'foo'"
exec_sql "create materialized view public.bad_domain_materialized_view_2 as select id,(body_binary::hive.transfer_operation).memo from hive.operations where hive.operation_id_to_type_id(id)=1"
exec_sql "comment on materialized view public.bad_domain_materialized_view_2 is 'bar'"
exec_sql "create materialized view public.bad_mixed_materialized_view_2 as select id,(body_binary::hive.transfer_operation).amount,(body_binary::hive.transfer_operation).memo from hive.operations where hive.operation_id_to_type_id(id)=1"
exec_sql "comment on materialized view public.bad_mixed_materialized_view_2 is 'baz'"
update_database
check_table_is_empty hive.deps_saved_ddl
check_relation_structure public.bad_type_materialized_view_2 "id|bigint|||\nbody_binary|hive.transfer_operation|||\namount|hive.asset|||"
check_relation_structure public.bad_domain_materialized_view_2 "id|bigint|||\nmemo|hive.memo|||"
check_relation_structure public.bad_mixed_materialized_view_2 "id|bigint|||\namount|hive.asset|||\nmemo|hive.memo|||"
check_relation_comment public.bad_type_materialized_view_2 foo
check_relation_comment public.bad_domain_materialized_view_2 bar
check_relation_comment public.bad_mixed_materialized_view_2 baz

printf "\nTEST: Check that function defined in hive namespace that doesn't reference current commit hash fails the upgrade.\n"
prepare_database
exec_sql "CREATE FUNCTION hive.bad_function() RETURNS VOID VOLATILE AS '/lib/postgresql/${POSTGRES_VERSION}/lib/tablefunc.so', 'crosstab' language c;"
failswith 3 update_database

echo "Succeeded"
