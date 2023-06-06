#!/bin/sh

# Test expects and calls three sql function in order:
# 1 - test_given() 2 - test_when() 3 - test_then()
# To pass the test all function must ends without errors




extension_path=$1
test_path=$2;
setup_scripts_dir_path=$3;
postgres_port=$4;
preload_libraries=$5;

. ./tools/common.sh

setup_test_database "$setup_scripts_dir_path" "$postgres_port" "$test_path" "$preload_libraries"

trap on_exit EXIT;

psql -p $postgres_port -d $DB_NAME -a -v ON_ERROR_STOP=on -f  ./tools/test_tools.sql;

psql -p $postgres_port -d $DB_NAME -a -v ON_ERROR_STOP=on -f  ${test_path};
evaluate_result $?;

psql -p $postgres_port -d $DB_NAME -v ON_ERROR_STOP=on -c 'SELECT test_given()';
evaluate_result $?;

psql -p $postgres_port -d $DB_NAME -v ON_ERROR_STOP=on -c 'SELECT test_when()';
evaluate_result $?;

psql -p $postgres_port -d $DB_NAME -v ON_ERROR_STOP=on -c 'SELECT test_then()';
evaluate_result $?;

psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -c "DROP DATABASE $DB_NAME";

on_exit
echo "PASSED";
exit 0;


