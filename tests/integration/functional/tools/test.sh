#!/bin/sh

extension_path=$1
test_path=$2;
setup_scripts_dir_path=$3;
postgres_port=$4;

. ./tools/common.sh

setup_test_database "$setup_scripts_dir_path" "$postgres_port" "$test_path"

trap on_exit EXIT;

psql -p $postgres_port -d $DB_NAME -a -v ON_ERROR_STOP=on -f  ./tools/test_tools.sql;

# add test functions:
# load tests function
psql -p $postgres_port -d $DB_NAME -a -v ON_ERROR_STOP=on -f  ${test_path};

users="haf_admin test_hived alice bob"
tests="given when error then"

# you can use alice_test_given, alice_test_when, alice_test_error, alice_test_then and their bob's and test_hived equivalents

for testfun in ${tests}; do
  for user in ${users}; do
    sql_code_no_error="DO \$\$
    BEGIN
      BEGIN
        PERFORM ${user}_test_${testfun}();
      EXCEPTION WHEN undefined_function THEN
      END;
    END \$\$;"

    sql_code_error="SELECT ${user}_test_${testfun}();";

    if [ "$user" =  "haf_admin" ]; then
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

on_exit
psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -c "DROP DATABASE \"$DB_NAME\"";

echo "PASSED";
trap - EXIT;
exit 0;

