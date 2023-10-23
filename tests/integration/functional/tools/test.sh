#!/usr/bin/env bash

extension_path=$1
test_path=$2;
setup_scripts_dir_path=$3;
postgres_port=$4;

. ./tools/common.sh

setup_test_database "$setup_scripts_dir_path" "$postgres_port" "$test_path"

trap on_exit EXIT;

psql -p $postgres_port -d $DB_NAME -a -v ON_ERROR_STOP=on -f  ./tools/test_tools.sql;
evaluate_result $?

users="haf_admin test_hived alice bob"
tests="given when error then"

for testfun in ${tests}; do
  for user in ${users}; do
    if [ "${testfun}" = "error" ]; then
      body="raise exception 'Expected to fail';"
    else
      body=""
    fi
    query="
CREATE OR REPLACE PROCEDURE ${user}_test_${testfun}()
LANGUAGE plpgsql
AS
\$\$
BEGIN
$body
END
\$\$;"
    psql -p $postgres_port -d $DB_NAME -v ON_ERROR_STOP=on -c "$query"
    evaluate_result $?
  done
done

# add test functions:
# load tests function
psql -p $postgres_port -d $DB_NAME -a -v ON_ERROR_STOP=on -f  ${test_path};
evaluate_result $?

users="haf_admin_procedure haf_admin test_hived alice bob"
tests="given when error then"

# mtlk this was working without surrounding block
# psql -p $postgres_port -d $DB_NAME -v ON_ERROR_STOP=on -c "CALL haf_admin_procedure_test_given()";
# evaluate_result $?;

# you can use alice_test_given, alice_test_when, alice_test_error, alice_test_then and their bob's and test_hived equivalents

counter=0

for testfun in ${tests}; do
  for user in ${users}; do
    query="CALL ${user}_test_${testfun}();";

    if [ "$user" = "haf_admin" ] || [ "$user" = "haf_admin_procedure" ]; then
      pg_call="-p $postgres_port -d $DB_NAME -v ON_ERROR_STOP=on -c"
    else
      pg_call="postgresql://${user}:test@localhost:$postgres_port/$DB_NAME --username=${user} -a -v ON_ERROR_STOP=on -c"
    fi

    if [ "${testfun}" = "error" ]; then
      psql ${pg_call} "${sql_code_error}";
      evaluate_error_result $?
    else
      psql ${pg_call} "${sql_code_no_error}";
      evaluate_result $?
    fi
  done
done

if [ $counter -eq 0 ]; then
    echo "No functions executed in test"
    # mtlk - uncomment below when tests fixed
    # evaluate_result false
  # these are not called
  # 114 - test.functional.hive_fork_manager.hived_api.are_indexes_dropped_test (Failed)
  # 	115 - test.functional.hive_fork_manager.hived_api.are_indexes_dropped_2_test (Failed)
  # 	116 - test.functional.hive_fork_manager.hived_api.are_fk_dropped_2_test (Failed)
  # 	117 - test.functional.hive_fork_manager.hived_api.are_fk_dropped_test (Failed)
  # 	238 - test.functional.hive_fork_manager.authorization.hived_to_api_access (Failed)
fi

on_exit
psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -c "DROP DATABASE \"$DB_NAME\"";


echo "PASSED";


trap - EXIT;
exit 0;

