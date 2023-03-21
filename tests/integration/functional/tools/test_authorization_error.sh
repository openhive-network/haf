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

users="alice bob"
tests="given when error"

# you can use alice_test_given, alice_tes_when, alice_test_error and their bob's equivalents

for user in ${users}; do
  for testfun in ${tests}; do
    sql_code="DO \$$
    BEGIN
      BEGIN
        PERFORM '${user}_test_${testfun}()'::regprocedure;
      EXCEPTION WHEN undefined_function THEN
      END;
    END \$$;"

    psql postgresql://${user}:test@localhost:$postgres_port/$DB_NAME --username=${user} -a -v ON_ERROR_STOP=on -c "${sql_code}";
    result=$?;

    # shellcheck disable=SC2170
    if [ "${testfun}" == "error" ]; then
      valuate_error_result ${result}
    else
      evaluate_result ${result}
    fi
  done
done

psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -c "DROP DATABASE $DB_NAME";

echo "PASSED";
exit 0;

