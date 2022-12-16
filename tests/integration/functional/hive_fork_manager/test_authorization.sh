#!/bin/sh

extension_path=$1
test_path=$2;
setup_scripts_dir_path=$3;
postgres_port=$4;

. ./common.sh

setup_test_database "$setup_scripts_dir_path" "$postgres_port"

# add test functions:
# load tests function
psql -p $postgres_port -d $DB_NAME -a -v ON_ERROR_STOP=on -f  ${test_path};

# GIVEN
psql postgresql://test_hived:test@localhost:$postgres_port/$DB_NAME --username=test_hived -a -v ON_ERROR_STOP=on -c 'SELECT hived_test_given()';
evaluate_result $?;
psql postgresql://alice:test@localhost:$postgres_port/$DB_NAME --username=alice -a -v ON_ERROR_STOP=on -c 'SELECT alice_test_given()';
evaluate_result $?;
psql postgresql://bob:test@localhost:$postgres_port/$DB_NAME --username=bob -a -v ON_ERROR_STOP=on -c 'SELECT bob_test_given()';
evaluate_result $?;

# WHEN
psql postgresql://test_hived:test@localhost:$postgres_port/$DB_NAME --username=test_hived -a -v ON_ERROR_STOP=on -c 'SELECT hived_test_when()';
evaluate_result $?;
psql postgresql://alice:test@localhost:$postgres_port/$DB_NAME --username=alice -a -v ON_ERROR_STOP=on -c 'SELECT alice_test_when()';
evaluate_result $?;
psql postgresql://bob:test@localhost:$postgres_port/$DB_NAME --username=bob -a -v ON_ERROR_STOP=on -c 'SELECT bob_test_when()';
evaluate_result $?;

# THEN
psql postgresql://test_hived:test@localhost:$postgres_port/$DB_NAME --username=test_hived -a -v ON_ERROR_STOP=on -c 'SELECT hived_test_then()';
evaluate_result $?;
psql postgresql://alice:test@localhost:$postgres_port/$DB_NAME --username=alice -a -v ON_ERROR_STOP=on -c 'SELECT alice_test_then()';
evaluate_result $?;
psql postgresql://bob:test@localhost:$postgres_port/$DB_NAME --username=bob -a -v ON_ERROR_STOP=on -c 'SELECT bob_test_then()';
evaluate_result $?;

psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -c "DROP DATABASE $DB_NAME";

echo "PASSED";
exit 0;

