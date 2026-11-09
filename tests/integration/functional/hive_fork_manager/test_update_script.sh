#!/usr/bin/env bash
#
# Check that hive_fork_manager_update_script_generator.sh fails when it's supposed to fail
#
set -eu -o pipefail

SCRIPTPATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
SCRIPTS_DIR="$SCRIPTPATH/../../../../scripts"
UPDATE_DB_NAME=update_db_test
POSTGRES_VERSION="${POSTGRES_VERSION:-17}"

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

EXTENSION_DIR="/usr/share/postgresql/$POSTGRES_VERSION/extension"

# The install script of the version CREATE EXTENSION installs by default, not the newest file: the
# scripts this test writes are newer.
default_sql_script() {
    echo "$EXTENSION_DIR/hive_fork_manager--$(sed -nE "s/^default_version = '(.*)'$/\1/p" "$EXTENSION_DIR/hive_fork_manager.control").sql"
}

prepare_sql_script() {
    version="$1"
    # remove any existing sql script with given version
    sudo rm -f "$EXTENSION_DIR/hive_fork_manager--$version.sql"
    sudo cp "$(default_sql_script)" "$EXTENSION_DIR/hive_fork_manager--$version.sql"
}

# A version that still has the KEYAUTH state provider: the current install script without the refusal in
# hive.app_state_provider_import, and with the provider's functions as the last version having it shipped them.
prepare_pre_keyauth_removal_sql_script() {
    version="$1"
    script="$EXTENSION_DIR/hive_fork_manager--$version.sql"
    sudo rm -f "$script"
    sed "/^    IF _state_provider = 'KEYAUTH' THEN$/,/^    END IF;$/d" "$(default_sql_script)" \
        | cat - "$SCRIPTPATH/pre_417_keyauth_provider.sql" | sudo tee "$script" > /dev/null
    if grep -q "The KEYAUTH state provider was removed from HAF" "$script"; then
        echo "TEST FAILED: could not remove the KEYAUTH refusal from hive.app_state_provider_import"
        exit 42
    fi
}

prepare_database() {
    "$SCRIPTS_DIR/setup_db.sh" --haf-db-name="$UPDATE_DB_NAME" "$@"
    exec_sql "SELECT hive.initialize_extension_data();"
}

update_database() {
    exec_sql "UPDATE pg_extension SET extversion = '1.0' WHERE extname = 'hive_fork_manager';"
    # The installed generator, not the one cmake configured in $HAF_DIR: a reused image carries
    # only the update script of the commit it was built from, which can differ from HEAD.
    sudo "/usr/share/postgresql/$POSTGRES_VERSION/extension/hive_fork_manager_update_script_generator.sh" --haf-db-name="$UPDATE_DB_NAME"
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
    psql -w -d "$UPDATE_DB_NAME" -v ON_ERROR_STOP=on -q -t -A -c "$1"
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

make_account_operations_uq1_outdated() {
    exec_sql "ALTER TABLE hafd.account_operations DROP CONSTRAINT hive_account_operations_uq1;
              ALTER TABLE hafd.account_operations ADD CONSTRAINT hive_account_operations_uq1 UNIQUE (account_id, account_op_seq_no);
              ALTER TABLE hafd.account_operations CLUSTER ON hive_account_operations_uq1;"
}

# A HAF image ships only its own libhfm, so on a real upgrade the C functions of the deployed
# extension (version 1.0, see update_database) point at a library that does not exist.
unship_deployed_libhfm() {
    exec_sql "UPDATE pg_proc SET probin = '\$libdir/libhfm-1.0.so' WHERE probin LIKE '%/libhfm-%'"
}

check_hive_event_triggers_use_new_libhfm() {
    if [ "$(exec_sql "SELECT count(*) FROM pg_event_trigger e JOIN pg_proc p ON p.oid = e.evtfoid
                      WHERE p.pronamespace = 'hive'::regnamespace AND e.evtenabled = 'O'")" != "3" ]; then
        echo "TEST FAILED: hive's event triggers are not all enabled after the update"
        return 27
    fi
    if [ "$(exec_sql "SELECT probin FROM pg_proc WHERE oid = 'hive.ignore_registered_table_edition(pg_ddl_command)'::regprocedure")" = "\$libdir/libhfm-1.0.so" ]; then
        echo "TEST FAILED: hive.ignore_registered_table_edition still references the deployed libhfm"
        return 28
    fi
    # an ALTER TABLE runs hive.on_edit_registered_tables, which loads the library of hive.ignore_registered_table_edition
    exec_sql "CREATE TABLE public.altered_after_update(id INT); ALTER TABLE public.altered_after_update ADD COLUMN v INT;"
}

# The hafd schema of the last release before hafd.custom_json_type_index_requests: without the tables,
# columns and storage options added since, which the update has to add.
make_hafd_schema_of_last_release() {
    exec_sql "ALTER EXTENSION hive_fork_manager DROP TABLE hafd.custom_json_type_index_requests;
              DROP TABLE hafd.custom_json_type_index_requests;
              ALTER TABLE hafd.contexts DROP COLUMN early_block_processing;
              ALTER TABLE hafd.applications DROP COLUMN health_function;
              ALTER TABLE hafd.indexes_constraints DROP COLUMN massive_sync_class;
              ALTER TABLE hafd.vacuum_requests DROP CONSTRAINT pk_hive_vacuum_requests;
              ALTER TABLE hafd.vacuum_requests DROP COLUMN kind, DROP COLUMN skip_count, DROP COLUMN first_skip_time;
              ALTER TABLE hafd.vacuum_requests ADD CONSTRAINT pk_hive_vacuum_requests UNIQUE( schema_name, table_name );
              ALTER TABLE hafd.contexts RESET ( vacuum_truncate );
              ALTER TABLE hafd.hive_state RESET ( vacuum_truncate );
              ALTER TABLE hafd.operations RESET ( autovacuum_vacuum_insert_scale_factor );
              ALTER TABLE hafd.transactions RESET ( autovacuum_vacuum_insert_scale_factor );
              ALTER TABLE hafd.blocks RESET ( autovacuum_vacuum_insert_scale_factor );"
}

# The schema hash the update verifies, and what it leaves out: owner, privileges, storage options,
# extension membership and pg_dump registration of every hafd table, and the full definition of the
# table the update creates.
hafd_schema_snapshot() {
    psql -w -d "$UPDATE_DB_NAME" -v ON_ERROR_STOP=on -q -t -A -f "/usr/share/postgresql/$POSTGRES_VERSION/extension/update.sql" > /dev/null
    exec_sql "SELECT hive_update.create_database_hash()"
    exec_sql "SELECT c.relname, pg_get_userbyid(c.relowner), c.relacl::text, c.reloptions::text,
                     EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.deptype = 'e'),
                     c.oid = ANY (SELECT unnest(extconfig) FROM pg_extension WHERE extname = 'hive_fork_manager')
              FROM pg_class c WHERE c.relnamespace = 'hafd'::regnamespace AND c.relkind = 'r' ORDER BY 1"
    exec_sql "\d hafd.custom_json_type_index_requests"
}

check_hafd_schema_equals() {
    actual=$(hafd_schema_snapshot)
    if [ "$1" != "$actual" ]; then
        printf "TEST FAILED: the hafd schema differs from a fresh install's after the update:\nExpected:\n%s\nActual:\n%s\n" "$1" "$actual"
        return 32
    fi
}

check_hive_update_helpers_present() {
    if [ "$(exec_sql "SELECT count(*) FROM pg_proc WHERE oid IN ('hive_update.save_hive_dependents()'::regprocedure, 'hive_update.restore_hive_dependents()'::regprocedure)")" != "2" ]; then
        echo "TEST FAILED: a failed update left the hive_update helpers dropped"
        return 29
    fi
}

index_oid() {
    exec_sql "SELECT 'hafd.$1'::regclass::oid"
}

check_account_operations_uq1() {
    expected="UNIQUE (account_id, account_op_seq_no) INCLUDE (op_type_id)"
    actual=$(exec_sql "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'hafd.account_operations'::regclass AND conname = 'hive_account_operations_uq1'")
    if [ "$expected" != "$actual" ]; then
        echo "TEST FAILED: hive_account_operations_uq1 expected to be '$expected', but is '$actual'"
        return 6
    fi
}

create_app_depending_on_hive() {
    exec_sql "DO \$\$ BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'update_test_app_owner') THEN CREATE ROLE update_test_app_owner IN ROLE hive_applications_owner_group; END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'update_test_app_reader') THEN CREATE ROLE update_test_app_reader; END IF;
              END \$\$;
              CREATE SCHEMA update_test_app AUTHORIZATION update_test_app_owner;
              SET ROLE update_test_app_owner;
              CREATE PROCEDURE update_test_app.process_blocks(_context hive.context_name, _blocks hive.blocks_range)
                  LANGUAGE plpgsql AS \$\$ BEGIN RAISE NOTICE 'processing %', _blocks; END \$\$;
              CREATE FUNCTION update_test_app.next_range(_last INT) RETURNS hive.blocks_range
                  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = update_test_app
                  AS \$\$ SELECT ROW(_last + 1, _last + 1000)::hive.blocks_range \$\$;
              CREATE FUNCTION update_test_app.current_age(_context TEXT DEFAULT hive.get_app_current_block_age('update_test_app')::TEXT) RETURNS TEXT
                  LANGUAGE sql AS \$\$ SELECT _context \$\$;
              CREATE VIEW update_test_app.next_range_view AS SELECT (update_test_app.next_range(10)).first_block AS first_block;
              CREATE VIEW update_test_app.ranges_view AS SELECT first_block FROM update_test_app.next_range_view;
              CREATE MATERIALIZED VIEW update_test_app.ranges_matview AS SELECT (update_test_app.next_range(g)).* FROM generate_series(1, 3) AS g;
              CREATE UNIQUE INDEX ranges_matview_first_block ON update_test_app.ranges_matview (first_block);
              REVOKE ALL ON PROCEDURE update_test_app.process_blocks(hive.context_name, hive.blocks_range) FROM PUBLIC;
              GRANT EXECUTE ON PROCEDURE update_test_app.process_blocks(hive.context_name, hive.blocks_range) TO update_test_app_reader;
              GRANT EXECUTE ON FUNCTION update_test_app.next_range(INT) TO update_test_app_reader WITH GRANT OPTION;
              GRANT SELECT ON update_test_app.ranges_view TO update_test_app_reader;
              COMMENT ON PROCEDURE update_test_app.process_blocks(hive.context_name, hive.blocks_range) IS 'processes a range';
              COMMENT ON FUNCTION update_test_app.next_range(INT) IS 'next range';
              CREATE TYPE update_test_app.break_reason AS ENUM ('done', 'stopped');
              CREATE PROCEDURE update_test_app.worker_loop(_context hive.context_name)
                  LANGUAGE plpgsql SET search_path TO update_test_app
                  AS \$\$ DECLARE __reason break_reason := 'done'; BEGIN RAISE NOTICE '% %', _context, __reason; END \$\$;
              SET search_path TO update_test_app, public;
              CREATE FUNCTION update_test_app.scheduler(_context hive.context_name) RETURNS TEXT
                  LANGUAGE plpgsql AS \$\$ DECLARE __reason break_reason := 'stopped'; BEGIN RETURN _context || __reason; END \$\$;
              RESET search_path;
              CREATE PROCEDURE update_test_app.process_blocks_buffered(_context hive.context_name)
                  LANGUAGE plpgsql SET temp_buffers = 2048
                  AS \$\$ BEGIN RAISE NOTICE 'processing %', _context; END \$\$;
              -- valid, as pg_restore creates it, but no session can apply this SET clause while creating the function
              SET check_function_bodies = off;
              CREATE FUNCTION update_test_app.missing_tablespace(_context hive.context_name) RETURNS TEXT
                  LANGUAGE sql SET default_tablespace = 'update_test_missing_tablespace'
                  AS \$\$ SELECT _context::TEXT \$\$;
              RESET check_function_bodies;
              RESET ROLE;"
}

# Definition, owner, privileges and comment of every routine, view and index of update_test_app.
app_objects_snapshot() {
    exec_sql "SELECT p.oid::regprocedure::text, pg_get_functiondef(p.oid), pg_get_userbyid(p.proowner), p.proacl::text, obj_description(p.oid, 'pg_proc')
              FROM pg_proc p WHERE p.pronamespace = 'update_test_app'::regnamespace
              UNION ALL
              SELECT c.oid::regclass::text, CASE WHEN c.relkind = 'i' THEN pg_get_indexdef(c.oid) ELSE pg_get_viewdef(c.oid) END,
                     pg_get_userbyid(c.relowner), c.relacl::text, obj_description(c.oid, 'pg_class')
              FROM pg_class c WHERE c.relnamespace = 'update_test_app'::regnamespace
              ORDER BY 1"
}

check_app_objects_unchanged() {
    actual=$(app_objects_snapshot)
    if [ "$1" != "$actual" ]; then
        printf "TEST FAILED: objects of update_test_app changed in the update:\nBefore:\n%s\nAfter:\n%s\n" "$1" "$actual"
        return 12
    fi
    if [ "$(exec_sql "SELECT count(*) FROM pg_class WHERE relnamespace = 'update_test_app'::regnamespace AND relkind IN ('v', 'm', 'i')")" != "4" ] \
        || [ "$(exec_sql "SELECT count(*) FROM pg_proc WHERE pronamespace = 'update_test_app'::regnamespace")" != "7" ]; then
        echo "TEST FAILED: update_test_app lost a view, an index or a routine"
        return 13
    fi
}

# Two contexts, as lite_account and lite_posts are, and app views spanning both contexts' views.
create_views_spanning_two_contexts() {
    exec_sql "DO \$\$ BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'span_test_owner') THEN CREATE ROLE span_test_owner IN ROLE hive_applications_owner_group; END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'span_test_reader') THEN CREATE ROLE span_test_reader; END IF;
              END \$\$;
              CREATE SCHEMA span_account AUTHORIZATION span_test_owner;
              CREATE SCHEMA span_posts AUTHORIZATION span_test_owner;
              SET ROLE span_test_owner;
              SELECT hive.app_create_context('span_account_ctx', 'span_account');
              SELECT hive.app_create_context('span_posts_ctx', 'span_posts');
              CREATE VIEW span_posts.profiles AS
                  SELECT a.num, a.hash AS account_hash, p.hash AS posts_hash
                  FROM span_account.blocks_view a JOIN span_posts.blocks_view p ON p.num = a.num;
              GRANT SELECT ON span_posts.profiles TO span_test_reader;
              COMMENT ON VIEW span_posts.profiles IS 'profiles of both contexts';
              CREATE VIEW span_account.profile_count AS SELECT count(*) AS profiles FROM span_posts.profiles;
              GRANT USAGE ON SCHEMA span_account TO span_test_reader;
              GRANT SELECT ON span_account.profile_count TO span_test_reader;
              RESET ROLE;" > /dev/null
}

# Definition, owner, privileges and comment of every view of the span_account and span_posts schemas.
span_views_snapshot() {
    exec_sql "SELECT c.oid::regclass::text, pg_get_viewdef(c.oid), pg_get_userbyid(c.relowner), c.relacl::text, obj_description(c.oid, 'pg_class')
              FROM pg_class c WHERE c.relnamespace IN ('span_account'::regnamespace, 'span_posts'::regnamespace) AND c.relkind = 'v'
              ORDER BY 1"
}

deployed_version() {
    exec_sql "SELECT extversion FROM pg_extension WHERE extname = 'hive_fork_manager'"
}

check_accepts_connections() {
    if [ "$(psql -w -d postgres -t -A -c "SELECT datallowconn FROM pg_database WHERE datname = '$UPDATE_DB_NAME'")" != "t" ] \
        || [ "$(exec_sql "SELECT 1")" != "1" ]; then
        echo "TEST FAILED: $UPDATE_DB_NAME does not accept connections after the update"
        return 14
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

printf "\nTEST: Creating table referencing hafd.operation. This is allowed and should succeed.\n"
prepare_database
exec_sql "create table public.good_table(id int, op hafd.operation)"
update_database
check_relation_structure public.good_table "id|integer|||\nop|hafd.operation|||"

printf "\nTEST: Creating table referencing disallowed HAF type. Upgrade should fail.\n"
prepare_database
exec_sql "create table public.bad_table(id int, comment hive.comment_operation)"
failswith 4 update_database
check_relation_structure public.bad_table "id|integer|||\ncomment|hive.comment_operation|||"

printf "\nTEST: Creating table referencing disallowed HAF domain. Upgrade should fail.\n"
prepare_database
exec_sql "create table public.bad_table(id int, extensions hive.extensions_type)"
failswith 4 update_database
check_relation_structure public.bad_table "id|integer|||\nextensions|hive.extensions_type|||"

printf "\nTEST: Creating table referencing allowed HAF domain. Upgrade should pass.\n"
prepare_database
exec_sql "create table public.good_table(id int, amount hafd.hive_amount)"
update_database
check_relation_structure public.good_table "id|integer|||\namount|hafd.hive_amount|||"

printf "\nTEST: Creating view referencing allowed types. This should pass\n"
prepare_database
exec_sql "create view public.good_view as select num, total_vesting_fund_hive, total_vesting_shares, current_hbd_supply, hbd_interest_rate from hafd.blocks"
exec_sql "comment on view public.good_view is 'foo'"
update_database
check_relation_structure public.good_view "num|integer|||\ntotal_vesting_fund_hive|hafd.hive_amount|||\ntotal_vesting_shares|hafd.vest_amount|||\ncurrent_hbd_supply|hafd.hbd_amount|||\nhbd_interest_rate|hafd.interest_rate|||"
check_relation_comment public.good_view foo

printf "\nTEST: Creating view referencing disallowed type. This should still pass and the view should be recreated.\n"
prepare_sql_script 0000000000000000000000000000000000000000
prepare_database --version="0000000000000000000000000000000000000000"
exec_sql "create view public.bad_type_view as select id,jsonb_populate_record(NULL::hive.transfer_operation, body_value),(jsonb_populate_record(NULL::hive.transfer_operation, body_value)).amount from hafd.operations where op_type_id=1"
exec_sql "comment on view public.bad_type_view is 'foo'"
exec_sql "create view public.bad_domain_view as select id,(jsonb_populate_record(NULL::hive.witness_set_properties_operation, body_value)).extensions from hafd.operations where op_type_id=42"
exec_sql "comment on view public.bad_domain_view is 'bar'"
exec_sql "create view public.bad_mixed_view as select id,(jsonb_populate_record(NULL::hive.transfer_operation, body_value)).amount,(jsonb_populate_record(NULL::hive.transfer_operation, body_value)).memo from hafd.operations where op_type_id=1"
exec_sql "comment on view public.bad_mixed_view is 'baz'"
update_database
check_table_is_empty hafd.deps_saved_ddl
check_relation_structure public.bad_type_view "id|bigint|||\njsonb_populate_record|hive.transfer_operation|||\namount|hive.asset|||"
check_relation_structure public.bad_domain_view "id|bigint|||\nextensions|hive.extensions_type|||"
check_relation_structure public.bad_mixed_view "id|bigint|||\namount|hive.asset|||\nmemo|hafd.memo|||"
check_relation_comment public.bad_type_view foo
check_relation_comment public.bad_domain_view bar
check_relation_comment public.bad_mixed_view baz

printf "\nTEST: Creating view referencing disallowed type with no update taking place. This should pass and the view should be recreated.\n"
prepare_database
exec_sql "create view public.bad_type_view_2 as select id,jsonb_populate_record(NULL::hive.transfer_operation, body_value),(jsonb_populate_record(NULL::hive.transfer_operation, body_value)).amount from hafd.operations where op_type_id=1"
exec_sql "comment on view public.bad_type_view_2 is 'foo'"
exec_sql "create view public.bad_domain_view_2 as select id,(jsonb_populate_record(NULL::hive.witness_set_properties_operation, body_value)).extensions from hafd.operations where op_type_id=42"
exec_sql "comment on view public.bad_domain_view_2 is 'bar'"
exec_sql "create view public.bad_mixed_view_2 as select id,(jsonb_populate_record(NULL::hive.transfer_operation, body_value)).amount,(jsonb_populate_record(NULL::hive.transfer_operation, body_value)).memo from hafd.operations where op_type_id=1"
exec_sql "comment on view public.bad_mixed_view_2 is 'baz'"
update_database
check_table_is_empty hafd.deps_saved_ddl
check_relation_structure public.bad_type_view_2 "id|bigint|||\njsonb_populate_record|hive.transfer_operation|||\namount|hive.asset|||"
check_relation_structure public.bad_domain_view_2 "id|bigint|||\nextensions|hive.extensions_type|||"
check_relation_structure public.bad_mixed_view_2 "id|bigint|||\namount|hive.asset|||\nmemo|hafd.memo|||"
check_relation_comment public.bad_type_view_2 foo
check_relation_comment public.bad_domain_view_2 bar
check_relation_comment public.bad_mixed_view_2 baz

printf "\nTEST: Creating materialized view referencing allowed types. This should pass\n"
prepare_database
exec_sql "create materialized view public.good_materialized_view as select num, total_vesting_fund_hive, total_vesting_shares, current_hbd_supply, hbd_interest_rate from hafd.blocks"
exec_sql "comment on materialized view public.good_materialized_view is 'foo'"
update_database
check_relation_structure public.good_materialized_view "num|integer|||\ntotal_vesting_fund_hive|hafd.hive_amount|||\ntotal_vesting_shares|hafd.vest_amount|||\ncurrent_hbd_supply|hafd.hbd_amount|||\nhbd_interest_rate|hafd.interest_rate|||"
check_relation_comment public.good_materialized_view foo

printf "\nTEST: Creating materialized view referencing disallowed type. This should still pass and the view should be recreated.\n"
prepare_sql_script 0000000000000000000000000000000000000000
prepare_database --version="0000000000000000000000000000000000000000"
exec_sql "create materialized view public.bad_type_materialized_view as select id,jsonb_populate_record(NULL::hive.transfer_operation, body_value),(jsonb_populate_record(NULL::hive.transfer_operation, body_value)).amount from hafd.operations where op_type_id=1"
exec_sql "comment on materialized view public.bad_type_materialized_view is 'foo'"
exec_sql "create materialized view public.bad_domain_materialized_view as select id,(jsonb_populate_record(NULL::hive.witness_set_properties_operation, body_value)).extensions from hafd.operations where op_type_id=42"
exec_sql "comment on materialized view public.bad_domain_materialized_view is 'bar'"
exec_sql "create materialized view public.bad_mixed_materialized_view as select id,(jsonb_populate_record(NULL::hive.transfer_operation, body_value)).amount,(jsonb_populate_record(NULL::hive.transfer_operation, body_value)).memo from hafd.operations where op_type_id=1"
exec_sql "comment on materialized view public.bad_mixed_materialized_view is 'baz'"
update_database
check_table_is_empty hafd.deps_saved_ddl
check_relation_structure public.bad_type_materialized_view "id|bigint|||\njsonb_populate_record|hive.transfer_operation|||\namount|hive.asset|||"
check_relation_structure public.bad_domain_materialized_view "id|bigint|||\nextensions|hive.extensions_type|||"
check_relation_structure public.bad_mixed_materialized_view "id|bigint|||\namount|hive.asset|||\nmemo|hafd.memo|||"
check_relation_comment public.bad_type_materialized_view foo
check_relation_comment public.bad_domain_materialized_view bar
check_relation_comment public.bad_mixed_materialized_view baz

printf "\nTEST: Creating materialized view referencing disallowed type with no update taking place. This should pass and the view should be recreated.\n"
prepare_database
exec_sql "create materialized view public.bad_type_materialized_view_2 as select id,jsonb_populate_record(NULL::hive.transfer_operation, body_value),(jsonb_populate_record(NULL::hive.transfer_operation, body_value)).amount from hafd.operations where op_type_id=1"
exec_sql "comment on materialized view public.bad_type_materialized_view_2 is 'foo'"
exec_sql "create materialized view public.bad_domain_materialized_view_2 as select id,(jsonb_populate_record(NULL::hive.witness_set_properties_operation, body_value)).extensions from hafd.operations where op_type_id=42"
exec_sql "comment on materialized view public.bad_domain_materialized_view_2 is 'bar'"
exec_sql "create materialized view public.bad_mixed_materialized_view_2 as select id,(jsonb_populate_record(NULL::hive.transfer_operation, body_value)).amount,(jsonb_populate_record(NULL::hive.transfer_operation, body_value)).memo from hafd.operations where op_type_id=1"
exec_sql "comment on materialized view public.bad_mixed_materialized_view_2 is 'baz'"
update_database
check_table_is_empty hafd.deps_saved_ddl
check_relation_structure public.bad_type_materialized_view_2 "id|bigint|||\njsonb_populate_record|hive.transfer_operation|||\namount|hive.asset|||"
check_relation_structure public.bad_domain_materialized_view_2 "id|bigint|||\nextensions|hive.extensions_type|||"
check_relation_structure public.bad_mixed_materialized_view_2 "id|bigint|||\namount|hive.asset|||\nmemo|hafd.memo|||"
check_relation_comment public.bad_type_materialized_view_2 foo
check_relation_comment public.bad_domain_materialized_view_2 bar
check_relation_comment public.bad_mixed_materialized_view_2 baz

printf "\nTEST: Check that function defined in hafd namespace that doesn't reference current commit hash fails the upgrade.\n"
prepare_database
exec_sql "CREATE FUNCTION hafd.bad_function() RETURNS VOID VOLATILE AS '/lib/postgresql/${POSTGRES_VERSION}/lib/tablefunc.so', 'crosstab' language c;"
failswith 3 update_database

printf "\nTEST: Change metadata state provider, but not use it. This should pass\n"
prepare_database
exec_sql "CREATE OR REPLACE FUNCTION hive.start_provider_metadata( _context hafd.context_name )
             RETURNS TEXT[]
             LANGUAGE plpgsql
             VOLATILE
             AS
             \$\$
             BEGIN
                 RETURN '';
             END;
             \$\$
             ;"
update_database

printf "\nTEST: Change metadata state provider, and use it. This should fail\n"
prepare_database
exec_sql "CREATE SCHEMA workaround;
          SELECT hive.app_create_context('workaround', 'workaround');
          SELECT hive.app_state_provider_import( 'METADATA', 'workaround' );
          "
exec_sql "CREATE OR REPLACE FUNCTION hive.start_provider_metadata( _context hafd.context_name )
             RETURNS TEXT[]
             LANGUAGE plpgsql
             VOLATILE
             AS
             \$\$
             BEGIN
                 RETURN '';
             END;
             \$\$
             ;"
failswith 1 update_database


printf "\nTEST: Use state providers. This should pass\n"
prepare_database
exec_sql "CREATE SCHEMA workaround;
          SELECT hive.app_create_context('workaround', 'workaround');
          SELECT hive.app_state_provider_import( 'ACCOUNTS', 'workaround' );
          SELECT hive.app_state_provider_import( 'METADATA', 'workaround' );
          "
update_database

printf "\nTEST: Upgrade from a version having the KEYAUTH state provider a database where a context imported it. The update should refuse naming the context and leave the database unchanged.\n"
prepare_pre_keyauth_removal_sql_script 1111111111111111111111111111111111111111
prepare_database --version="1111111111111111111111111111111111111111"
exec_sql "CREATE SCHEMA workaround;
          SELECT hive.app_create_context('workaround', 'workaround');
          SELECT hive.app_state_provider_import( 'METADATA', 'workaround' );
          SELECT hive.app_state_provider_import( 'KEYAUTH', 'workaround' );
          SELECT hive.app_context_detach( 'workaround' );
          SELECT hive.app_state_providers_update( 1, 1, 'workaround' );"
keyauth_tables="SELECT count(*) FROM pg_class WHERE relnamespace = 'hafd'::regnamespace AND relkind = 'r' AND relname LIKE 'workaround\_%auth%'"
[ "$(exec_sql "$keyauth_tables")" = "4" ] || { echo "TEST FAILED: the deployed version did not create the KEYAUTH tables"; exit 43; }
update_output=$(failswith 6 update_database 2>&1) || { echo "$update_output"; exit 37; }
echo "$update_output"
grep -q "contexts still having KEYAUTH registered: workaround" <<< "$update_output" \
    && grep -q "l2_framework" <<< "$update_output" \
    || { echo "TEST FAILED: the refusal does not name the context and l2_framework"; exit 38; }
[ "$(deployed_version)" = "1.0" ] || { echo "TEST FAILED: a refused update left version $(deployed_version) deployed"; exit 39; }
check_accepts_connections
[ "$(exec_sql "SELECT count(*) FROM hafd.state_providers_registered WHERE state_provider = 'KEYAUTH'")" = "1" ] \
    && [ "$(exec_sql "$keyauth_tables")" = "4" ] \
    && [ -n "$(exec_sql "SELECT to_regprocedure('hive.workaround_insert_into_keyauth_a(integer, integer)')")" ] \
    || { echo "TEST FAILED: a refused update changed the KEYAUTH registration"; exit 40; }
# the context still runs its providers on the deployed version
exec_sql "SELECT hive.app_state_providers_update( 1, 1, 'workaround' );" > /dev/null

printf "\nTEST: Upgrade the same database once the operator dropped the KEYAUTH provider on the deployed version. This should pass.\n"
exec_sql "SELECT hive.app_state_provider_drop( 'KEYAUTH', 'workaround' );"
update_database
[ "$(deployed_version)" != "1.0" ] || { echo "TEST FAILED: the extension was not updated"; exit 41; }
[ "$(exec_sql "$keyauth_tables")" = "0" ] \
    && [ "$(exec_sql "SELECT array_agg(state_provider)::text FROM hafd.state_providers_registered")" = "{METADATA}" ] \
    && [ -z "$(exec_sql "SELECT to_regproc('hive.start_provider_keyauth')")" ] \
    || { echo "TEST FAILED: the updated database still has KEYAUTH objects"; exit 44; }
exec_sql "SELECT hive.app_state_providers_update( 1, 1, 'workaround' );" > /dev/null

printf "\nTEST: Upgrade a database whose hive_account_operations_uq1 lacks INCLUDE (op_type_id) and whose deployed libhfm is not shipped. The index should be rebuilt in place.\n"
prepare_database
make_account_operations_uq1_outdated
unship_deployed_libhfm
update_database
check_account_operations_uq1
[ "$(exec_sql "SELECT indisclustered FROM pg_index WHERE indexrelid = 'hafd.hive_account_operations_uq1'::regclass")" = "t" ] \
    || { echo "TEST FAILED: hafd.account_operations is no longer clustered on hive_account_operations_uq1"; exit 7; }
[ "$(exec_sql "SELECT count(*) FROM pg_indexes WHERE schemaname = 'hafd' AND indexname LIKE 'hive_account_operations_uq1%'")" = "1" ] \
    || { echo "TEST FAILED: a leftover hive_account_operations_uq1 index remains"; exit 8; }

printf "\nTEST: Upgrade a database where an earlier update built hive_account_operations_uq1_new but failed in the swap. The index should be reused.\n"
prepare_database
make_account_operations_uq1_outdated
exec_sql "CREATE UNIQUE INDEX hive_account_operations_uq1_new ON hafd.account_operations (account_id, account_op_seq_no) INCLUDE (op_type_id)"
uq1_new_oid=$(index_oid hive_account_operations_uq1_new)
unship_deployed_libhfm
update_database
check_account_operations_uq1
[ "$(index_oid hive_account_operations_uq1)" = "$uq1_new_oid" ] \
    || { echo "TEST FAILED: the valid hive_account_operations_uq1_new was not reused"; exit 9; }

printf "\nTEST: Upgrade a database where an earlier update was interrupted while building hive_account_operations_uq1_new. The index should be rebuilt.\n"
prepare_database
make_account_operations_uq1_outdated
exec_sql "CREATE UNIQUE INDEX hive_account_operations_uq1_new ON hafd.account_operations (account_id, account_op_seq_no) INCLUDE (op_type_id)"
uq1_new_oid=$(index_oid hive_account_operations_uq1_new)
exec_sql "UPDATE pg_index SET indisvalid = false WHERE indexrelid = $uq1_new_oid"
unship_deployed_libhfm
update_database
check_account_operations_uq1
[ "$(index_oid hive_account_operations_uq1)" != "$uq1_new_oid" ] \
    || { echo "TEST FAILED: the invalid hive_account_operations_uq1_new was swapped in instead of rebuilt"; exit 10; }
[ "$(exec_sql "SELECT indisvalid FROM pg_index WHERE indexrelid = 'hafd.hive_account_operations_uq1'::regclass")" = "t" ] \
    || { echo "TEST FAILED: hive_account_operations_uq1 is not valid"; exit 11; }

printf "\nTEST: Upgrade a database that lacks columns the update adds to hafd tables and whose event-trigger functions are bound to a libhfm that is not shipped. The columns should be added and the triggers bound to the new libhfm.\n"
prepare_database
exec_sql "ALTER TABLE hafd.vacuum_requests DROP COLUMN skip_count, DROP COLUMN first_skip_time"
unship_deployed_libhfm
update_database
[ "$(exec_sql "SELECT count(*) FROM information_schema.columns WHERE table_schema = 'hafd' AND table_name = 'vacuum_requests'
               AND column_name IN ('skip_count', 'first_skip_time')")" = "2" ] \
    || { echo "TEST FAILED: the update did not add the missing hafd columns"; exit 30; }
[ "$(deployed_version)" != "1.0" ] || { echo "TEST FAILED: the extension was not updated"; exit 31; }
check_hive_event_triggers_use_new_libhfm

printf "\nTEST: Upgrade a database with the hafd schema of the last release before hafd.custom_json_type_index_requests. The update should bring it to a fresh install's schema.\n"
prepare_database
fresh_schema=$(hafd_schema_snapshot)
make_hafd_schema_of_last_release
unship_deployed_libhfm
update_database
[ "$(deployed_version)" != "1.0" ] || { echo "TEST FAILED: the extension was not updated"; exit 33; }
check_table_is_empty hafd.custom_json_type_index_requests
check_hafd_schema_equals "$fresh_schema"
exec_sql "CREATE SCHEMA cj_update_app;
          SELECT hive.app_create_context('cj_update_app', 'cj_update_app');
          SELECT hive.register_custom_json_type_index('cj_update_app', ARRAY['follow']);"
[ "$(exec_sql "SELECT custom_json_ids::text FROM hafd.custom_json_type_index_requests")" = "{follow}" ] \
    || { echo "TEST FAILED: hive.register_custom_json_type_index did not record its request on the updated database"; exit 34; }

printf "\nTEST: Upgrade a database with registered applications whose hafd.applications lacks health_function. The column should be added and the registrations kept.\n"
prepare_database
exec_sql "CREATE SCHEMA registry_update_app;
          CREATE PROCEDURE registry_update_app.process_blocks(_blocks hive.blocks_range) LANGUAGE plpgsql AS \$\$ BEGIN END \$\$;
          CREATE FUNCTION registry_update_app.health() RETURNS TEXT LANGUAGE sql AS \$\$ SELECT NULL::TEXT \$\$;
          SELECT hive.app_create_context('registry_update_ctx', 'registry_update_app');
          SELECT hive.app_create_context('registry_update_dep_ctx', 'registry_update_app');
          SELECT hive.app_register('registry_update_app', ARRAY['registry_update_ctx'], 'registry_update_app.process_blocks');
          SELECT hive.app_register('registry_update_dep', ARRAY['registry_update_dep_ctx']);
          SELECT hive.app_add_dependency('registry_update_dep', 'registry_update_app');
          SELECT hive.app_pause('registry_update_dep');
          ALTER TABLE hafd.applications DROP COLUMN health_function;"
registrations_before=$(exec_sql "SELECT name, contexts, process_procedure, completed_block_function, paused, owner FROM hafd.applications ORDER BY name")
update_database
[ "$(exec_sql "SELECT name, contexts, process_procedure, completed_block_function, paused, owner FROM hafd.applications ORDER BY name")" = "$registrations_before" ] \
    || { echo "TEST FAILED: the update changed the registrations in hafd.applications"; exit 45; }
[ "$(exec_sql "SELECT count(*) FROM hafd.applications WHERE health_function IS NULL")" = "2" ] \
    || { echo "TEST FAILED: the update did not add hafd.applications.health_function as NULL"; exit 46; }
[ "$(exec_sql "SELECT application || '>' || depends_on FROM hafd.application_dependencies")" = "registry_update_dep>registry_update_app" ] \
    || { echo "TEST FAILED: the update lost the dependency between the registered applications"; exit 47; }
exec_sql "SELECT hive.app_register('registry_update_app', ARRAY['registry_update_ctx'], 'registry_update_app.process_blocks', _health_function => 'registry_update_app.health')"
[ "$(exec_sql "SELECT health_function FROM hafd.applications WHERE name = 'registry_update_app'")" = "registry_update_app.health" ] \
    || { echo "TEST FAILED: hive.app_register did not record the health function on the updated database"; exit 48; }

printf "\nTEST: Upgrade a database that already has hafd.custom_json_type_index_requests. The table and its requests should be left as they are.\n"
prepare_database
exec_sql "CREATE SCHEMA cj_update_app;
          SELECT hive.app_create_context('cj_update_app', 'cj_update_app');
          SELECT hive.register_custom_json_type_index('cj_update_app', ARRAY['follow']);"
requests_oid=$(exec_sql "SELECT 'hafd.custom_json_type_index_requests'::regclass::oid")
requests_before=$(exec_sql "TABLE hafd.custom_json_type_index_requests")
update_database
[ "$(exec_sql "SELECT 'hafd.custom_json_type_index_requests'::regclass::oid")" = "$requests_oid" ] \
    || { echo "TEST FAILED: the update recreated hafd.custom_json_type_index_requests"; exit 35; }
[ "$(exec_sql "TABLE hafd.custom_json_type_index_requests")" = "$requests_before" ] \
    || { echo "TEST FAILED: the update changed the requests in hafd.custom_json_type_index_requests"; exit 36; }

printf "\nTEST: Upgrade a database whose hive_account_operations_uq1 is dropped for a massive sync. Its restore command should be updated.\n"
prepare_database
exec_sql "SELECT hive.save_and_drop_indexes_constraints('hafd', 'account_operations');
          UPDATE hafd.indexes_constraints
          SET command = 'ALTER TABLE hafd.account_operations ADD CONSTRAINT hive_account_operations_uq1 UNIQUE (account_id, account_op_seq_no)'
          WHERE index_constraint_name = 'hive_account_operations_uq1';"
update_database
exec_sql "SELECT hive.restore_indexes('hafd.account_operations');"
check_account_operations_uq1

printf "\nTEST: Upgrade a database with app routines and views that depend on hive types and functions. They should be restored unchanged.\n"
prepare_database
create_app_depending_on_hive
app_before=$(app_objects_snapshot)
update_database
check_table_is_empty hafd.deps_saved_ddl
check_app_objects_unchanged "$app_before"
exec_sql "CALL update_test_app.process_blocks('update_test_app', update_test_app.next_range(10))"
exec_sql "CALL update_test_app.worker_loop('update_test_app')"
exec_sql "CALL update_test_app.process_blocks_buffered('update_test_app')"

printf "\nTEST: Upgrade while another session holds a lock on a hive object. The session should be ended and the database reopened afterwards.\n"
prepare_database
create_app_depending_on_hive
app_before=$(app_objects_snapshot)
psql -w -d "$UPDATE_DB_NAME" -v ON_ERROR_STOP=on -c "BEGIN; LOCK TABLE hive.blocks_view IN ACCESS SHARE MODE; SELECT pg_sleep(600);" &
lock_holder=$!
until [ "$(exec_sql "SELECT count(*) FROM pg_locks WHERE relation = 'hive.blocks_view'::regclass AND granted AND pid <> pg_backend_pid()")" = "1" ]; do sleep 0.1; done
exec_sql "UPDATE pg_extension SET extversion = '1.0' WHERE extname = 'hive_fork_manager';"
sudo timeout 300 "/usr/share/postgresql/$POSTGRES_VERSION/extension/hive_fork_manager_update_script_generator.sh" --haf-db-name="$UPDATE_DB_NAME" \
    || { echo "TEST FAILED: the update did not complete while another session held a lock on a hive object"; exit 15; }
if wait "$lock_holder"; then
    echo "TEST FAILED: the session holding a lock on a hive object was not ended by the update"
    exit 16
fi
[ "$(deployed_version)" != "1.0" ] || { echo "TEST FAILED: the extension was not updated"; exit 17; }
check_accepts_connections
check_app_objects_unchanged "$app_before"

printf "\nTEST: Upgrade a database whose app view uses a hive function the new version lacks. The update should fail and leave the database on the old version, unchanged and accepting connections.\n"
prepare_database
create_app_depending_on_hive
exec_sql "CREATE FUNCTION hive.removed_in_new_version() RETURNS INT LANGUAGE sql AS 'SELECT 1';
          CREATE VIEW update_test_app.removed_function_view AS SELECT hive.removed_in_new_version() AS one;"
app_before=$(app_objects_snapshot)
update_output=$(failswith 1 update_database 2>&1) || { echo "$update_output"; exit 18; }
echo "$update_output"
grep -q "update_test_app.removed_function_view: function hive.removed_in_new_version() does not exist" <<< "$update_output" \
    || { echo "TEST FAILED: the failed restore of update_test_app.removed_function_view was not reported"; exit 19; }
[ "$(deployed_version)" = "1.0" ] || { echo "TEST FAILED: a failed update left version $(deployed_version) deployed"; exit 20; }
check_accepts_connections
check_table_is_empty hafd.deps_saved_ddl
[ "$(app_objects_snapshot)" = "$app_before" ] || { echo "TEST FAILED: a failed update changed update_test_app"; exit 21; }
[ "$(exec_sql "SELECT hive.removed_in_new_version()")" = "1" ] || { echo "TEST FAILED: a failed update changed the hive schema"; exit 22; }
check_hive_update_helpers_present

printf "\nTEST: Upgrade a database whose app table has a column default calling a hive function. The update should fail naming it, and leave the database unchanged.\n"
prepare_database
exec_sql "CREATE TABLE public.default_from_hive(age INTERVAL DEFAULT hive.get_app_current_block_age('x'))"
update_output=$(failswith 1 update_database 2>&1) || { echo "$update_output"; exit 23; }
echo "$update_output"
grep -q "cannot be restored: default value for public.default_from_hive.age" <<< "$update_output" \
    || { echo "TEST FAILED: the column default depending on hive was not named"; exit 24; }
[ "$(deployed_version)" = "1.0" ] || { echo "TEST FAILED: a failed update left version $(deployed_version) deployed"; exit 25; }
check_accepts_connections
[ -n "$(exec_sql "SELECT pg_get_expr(adbin, adrelid) FROM pg_attrdef WHERE adrelid = 'public.default_from_hive'::regclass")" ] \
    || { echo "TEST FAILED: a failed update dropped the column default"; exit 26; }

printf "\nTEST: Upgrade a database whose context views read their horizon from context_data_view. The update should recreate them in the current shape, keeping their owner and the app views built on them, and leave a detached context's views as they are.\n"
prepare_database
exec_sql "DO \$\$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'horizon_test_owner') THEN CREATE ROLE horizon_test_owner IN ROLE hive_applications_owner_group; END IF;
          END \$\$;
          CREATE SCHEMA horizon_app AUTHORIZATION horizon_test_owner;
          CREATE SCHEMA horizon_detached AUTHORIZATION horizon_test_owner;
          SET ROLE horizon_test_owner;
          SELECT hive.app_create_context('horizon_ctx', 'horizon_app');
          SELECT hive.app_create_context('horizon_detached_ctx', 'horizon_detached');
          SELECT hive.app_context_detach('horizon_detached_ctx');
          CREATE OR REPLACE VIEW horizon_app.blocks_view AS
              SELECT t.* FROM horizon_app.context_data_view c, LATERAL ( SELECT hb.* FROM hafd.blocks hb WHERE hb.num <= c.min_block ) t;
          CREATE OR REPLACE VIEW horizon_app.operations_view AS
              SELECT t.id, hafd.operation_id_to_block_num(t.id) AS block_num, t.trx_in_block, t.op_pos, t.op_type_id, t.body_value,
                     jsonb_build_object('type', ot.name, 'value', t.body_value) AS body, t.custom_json_type_id
              FROM horizon_app.context_data_view c,
              LATERAL ( SELECT ho.* FROM hafd.operations ho WHERE hafd.operation_id_to_block_num(ho.id) <= c.min_block ) t
              JOIN hafd.operation_types ot ON ot.id = t.op_type_id;
          CREATE VIEW horizon_app.last_block AS SELECT max(num) AS num FROM horizon_app.blocks_view;
          CREATE VIEW horizon_app.transaction_count AS SELECT count(*) AS transactions FROM horizon_app.transactions_view;
          RESET ROLE;"
reading_context_data_view="SELECT string_agg(c.relname, ',' ORDER BY c.relname) FROM pg_class c
    WHERE c.relnamespace = 'horizon_app'::regnamespace AND c.relkind = 'v' AND EXISTS (
        SELECT 1 FROM pg_rewrite r JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = r.oid
        WHERE r.ev_class = c.oid AND d.deptype = 'n' AND d.refobjid = 'horizon_app.context_data_view'::regclass)"
[ "$(exec_sql "$reading_context_data_view")" = "blocks_view,operations_view" ] \
    || { echo "TEST FAILED: could not give horizon_app the views of the previous shape"; exit 49; }
detached_views="SELECT string_agg(c.relname || ':' || pg_get_viewdef(c.oid), E'\n' ORDER BY c.relname) FROM pg_class c
    WHERE c.relnamespace = 'horizon_detached'::regnamespace AND c.relkind = 'v'"
detached_before=$(exec_sql "$detached_views")
update_database
[ -z "$(exec_sql "$reading_context_data_view")" ] \
    || { echo "TEST FAILED: views still reading context_data_view after the update: $(exec_sql "$reading_context_data_view")"; exit 50; }
[ "$(exec_sql "SELECT count(*) FROM pg_class c WHERE c.relnamespace = 'horizon_app'::regnamespace AND c.relkind = 'v'
               AND pg_get_viewdef(c.oid) LIKE '%hive.context_view_horizon(%'")" = "8" ] \
    || { echo "TEST FAILED: the 8 views of horizon_ctx do not read hive.context_view_horizon after the update"; exit 51; }
[ "$(exec_sql "SELECT string_agg(DISTINCT pg_get_userbyid(c.relowner), ',') FROM pg_class c WHERE c.relnamespace = 'horizon_app'::regnamespace AND c.relkind = 'v'")" = "horizon_test_owner" ] \
    || { echo "TEST FAILED: the update changed the owner of a view of horizon_ctx"; exit 52; }
[ "$(exec_sql "SELECT (SELECT num FROM horizon_app.last_block) IS NULL AND (SELECT transactions FROM horizon_app.transaction_count) = 0")" = "t" ] \
    || { echo "TEST FAILED: the app views built on the views of horizon_ctx do not work after the update"; exit 53; }
[ "$(exec_sql "$detached_views")" = "$detached_before" ] \
    || { echo "TEST FAILED: the update changed the views of the detached context"; exit 54; }

printf "\nTEST: Upgrade a database whose operations_view_extended reads the timestamp of an operation in a subquery, the shape it had when it began to read its horizon through hive.context_view_horizon. The update should recreate it in the current shape, keeping the app views built on it, and leave the other views as they are.\n"
prepare_database
exec_sql "DO \$\$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'shape_test_owner') THEN CREATE ROLE shape_test_owner IN ROLE hive_applications_owner_group; END IF;
          END \$\$;
          CREATE SCHEMA shape_app AUTHORIZATION shape_test_owner;
          SET ROLE shape_test_owner;
          SELECT hive.app_create_context('shape_ctx', 'shape_app');
          DO \$\$ BEGIN
            EXECUTE format(\$v\$CREATE OR REPLACE VIEW shape_app.operations_view_extended AS
              SELECT t.id, hafd.operation_id_to_block_num(t.id) AS block_num, t.trx_in_block, t.op_pos, t.op_type_id, t.timestamp, t.body_value,
                     jsonb_build_object('type', replace(ot.name, 'hive::protocol::', ''), 'value', t.body_value) AS body, t.custom_json_type_id
              FROM (
                SELECT 0 AS leg, ho.id, ho.trx_in_block, ho.op_pos, ho.op_type_id,
                       (SELECT b.created_at FROM hafd.blocks b WHERE b.num = hafd.operation_id_to_block_num(ho.id)) AS timestamp,
                       ho.body_value, ho.custom_json_type_id, NULL::BIGINT AS fork_id
                FROM hafd.operations ho
                UNION ALL
                SELECT 1 AS leg, o.id, o.trx_in_block, o.op_pos, o.op_type_id,
                       (SELECT b.created_at FROM hafd.blocks_reversible b WHERE b.num = hafd.operation_id_to_block_num(o.id) AND b.fork_id = o.fork_id) AS timestamp,
                       o.body_value, o.custom_json_type_id, o.fork_id
                FROM hafd.operations_reversible o
              ) t
              JOIN hafd.operation_types ot ON ot.id = t.op_type_id
              WHERE %s\$v\$, hive.context_view_legs_filter('shape_ctx', 'hafd.operation_id_to_block_num( t.id )'));
          END \$\$;
          COMMENT ON VIEW shape_app.operations_view_extended IS NULL;
          CREATE VIEW shape_app.operation_count AS SELECT count(*) AS operations FROM shape_app.operations_view_extended;
          RESET ROLE;"
reads_timestamp_in_subquery="SELECT pg_get_viewdef('shape_app.operations_view_extended'::regclass) LIKE '%SELECT b.created_at%'"
[ "$(exec_sql "$reads_timestamp_in_subquery")" = "t" ] \
    || { echo "TEST FAILED: could not give shape_app the operations_view_extended of the previous shape"; exit 55; }
other_shape_views="SELECT string_agg(c.relname || ':' || pg_get_viewdef(c.oid), E'\n' ORDER BY c.relname) FROM pg_class c
    WHERE c.relnamespace = 'shape_app'::regnamespace AND c.relkind = 'v' AND c.relname NOT IN ('operations_view_extended', 'operation_count')"
other_shape_views_before=$(exec_sql "$other_shape_views")
update_output=$(update_database 2>&1) || { echo "$update_output"; exit 56; }
echo "$update_output"
grep -q "Recreating shape_app.operations_view_extended" <<< "$update_output" \
    || { echo "TEST FAILED: the update did not recreate shape_app.operations_view_extended"; exit 57; }
[ "$(exec_sql "$reads_timestamp_in_subquery")" = "f" ] \
    || { echo "TEST FAILED: shape_app.operations_view_extended reads the timestamp in a subquery after the update"; exit 58; }
[ "$(exec_sql "SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'shape_app.operations_view_extended'::regclass")" = "shape_test_owner" ] \
    || { echo "TEST FAILED: the update changed the owner of shape_app.operations_view_extended"; exit 59; }
check_relation_comment shape_app.operations_view_extended "$(exec_sql "SELECT hive.context_view_shape('operations_view_extended')")" || exit 60
[ "$(exec_sql "SELECT operations FROM shape_app.operation_count")" = "0" ] \
    || { echo "TEST FAILED: the app view built on shape_app.operations_view_extended does not work after the update"; exit 61; }
[ "$(exec_sql "$other_shape_views")" = "$other_shape_views_before" ] \
    || { echo "TEST FAILED: the update changed the other views of shape_ctx"; exit 62; }
current_definition=$(exec_sql "SELECT pg_get_viewdef('shape_app.operations_view_extended'::regclass)")
exec_sql "SELECT hive.create_operations_view_extended('shape_ctx')" > /dev/null
[ "$(exec_sql "SELECT pg_get_viewdef('shape_app.operations_view_extended'::regclass)")" = "$current_definition" ] \
    || { echo "TEST FAILED: shape_app.operations_view_extended does not have the definition hive.create_operations_view_extended generates"; exit 63; }

printf "\nTEST: Upgrade a database with an app view built on the blocks_view of two contexts, and an app view built on it. The update should restore every view once, with its definition, owner, privileges and comment.\n"
prepare_database
create_views_spanning_two_contexts
span_before=$(span_views_snapshot)
update_output=$(update_database 2>&1) || { echo "$update_output"; exit 64; }
echo "$update_output"
check_table_is_empty hafd.deps_saved_ddl
[ "$(grep -c "Restoring span_posts.profiles" <<< "$update_output")" = "1" ] \
    || { echo "TEST FAILED: span_posts.profiles was not restored exactly once"; exit 65; }
span_after=$(span_views_snapshot)
[ "$span_after" = "$span_before" ] \
    || { printf "TEST FAILED: views of span_account and span_posts changed in the update:\nBefore:\n%s\nAfter:\n%s\n" "$span_before" "$span_after"; exit 66; }
[ "$(exec_sql "SET ROLE span_test_reader; SELECT profiles FROM span_account.profile_count")" = "0" ] \
    || { echo "TEST FAILED: the app views spanning two contexts do not work after the update"; exit 67; }

printf "\nTEST: Upgrade a database whose app view, built on an app view spanning two contexts, uses a hive function the new version lacks. The update should fail naming it, and leave the database unchanged.\n"
prepare_database
create_views_spanning_two_contexts
exec_sql "CREATE FUNCTION hive.removed_in_new_version() RETURNS INT LANGUAGE sql AS 'SELECT 1';
          CREATE VIEW span_posts.removed_function_view AS SELECT num, hive.removed_in_new_version() AS one FROM span_posts.profiles;"
span_before=$(span_views_snapshot)
update_output=$(failswith 1 update_database 2>&1) || { echo "$update_output"; exit 68; }
echo "$update_output"
grep -q "span_posts.removed_function_view: function hive.removed_in_new_version() does not exist" <<< "$update_output" \
    || { echo "TEST FAILED: the failed restore of span_posts.removed_function_view was not reported"; exit 69; }
if grep -q "^span_posts.profiles:" <<< "$update_output"; then
    echo "TEST FAILED: span_posts.profiles was reported as unrestorable"
    exit 70
fi
[ "$(deployed_version)" = "1.0" ] || { echo "TEST FAILED: a failed update left version $(deployed_version) deployed"; exit 71; }
check_accepts_connections
check_table_is_empty hafd.deps_saved_ddl
[ "$(span_views_snapshot)" = "$span_before" ] || { echo "TEST FAILED: a failed update changed the views of span_account and span_posts"; exit 72; }
check_hive_update_helpers_present

echo "Succeeded"
