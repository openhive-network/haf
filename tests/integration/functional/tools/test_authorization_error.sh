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

# you can use alice_test_given, alice_test_when, alice_test_error and their bob's equivalents

for user in ${users}; do
  for testfun in ${tests}; do
    sql_code_no_error="DO \$\$
    BEGIN
      BEGIN
        PERFORM ${user}_test_${testfun}();
      EXCEPTION WHEN undefined_function THEN
      END;
    END \$\$;"

    sql_code_error="SELECT ${user}_test_${testfun}();";

    if [ "${testfun}" = "error" ]; then
      psql postgresql://${user}:test@localhost:$postgres_port/$DB_NAME --username=${user} -a -v ON_ERROR_STOP=on -c "${sql_code_error}";
      evaluate_error_result $?
    else
      psql postgresql://${user}:test@localhost:$postgres_port/$DB_NAME --username=${user} -a -v ON_ERROR_STOP=on -c "${sql_code_no_error}";
      evaluate_result $?
    fi
  done
done

on_exit
psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -c "DROP DATABASE $DB_NAME";

echo "PASSED";
exit 0;

