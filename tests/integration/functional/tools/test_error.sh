#!/bin/sh

# Test expects and calls two sql function in order:
# 1 - test_given() 2 - test_error()
# To pass the test test_given must return without error and test error must return with error
# This kind of tests are required to test errors which cannot be handled like. breaking query by query supervisor

extension_path=$1
test_path=$2;
setup_scripts_dir_path=$3;
postgres_port=$4;

. ./tools/common.sh

setup_test_database "$setup_scripts_dir_path" "$postgres_port" "$test_path"

trap on_exit EXIT;

psql -p $postgres_port -d $DB_NAME -a -v ON_ERROR_STOP=on -f  ./tools/test_tools.sql;

psql -p $postgres_port -d $DB_NAME -a -v ON_ERROR_STOP=on -f  ${test_path};
evaluate_result $?;

psql -p $postgres_port -d $DB_NAME -v ON_ERROR_STOP=on -c 'SELECT test_given()';
evaluate_result $?;

psql -p $postgres_port -d $DB_NAME -v ON_ERROR_STOP=on -c 'SELECT test_error()';
evaluate_error_result $?;

on_exit
psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -c "DROP DATABASE $DB_NAME";

echo "PASSED";
exit 0;


