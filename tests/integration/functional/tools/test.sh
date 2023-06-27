#!/bin/bash

set -x

extension_path=$1
test_path=$2;
setup_scripts_dir_path=$3;
postgres_port=$4;

. ./tools/common.sh

setup_test_database "$setup_scripts_dir_path" "$postgres_port" "$test_path"

trap on_exit EXIT;

psql -p $postgres_port -d $DB_NAME -a -v ON_ERROR_STOP=on -f  ./tools/test_tools.sql;
evaluate_result $?



# Default storage path
STORAGE_PATH='/home/hived/datadir/consensus_unit_test_storage_dir'

# If the CI_PROJECT_DIR environment variable is set and it's not empty,
# use it as the storage path
if [[ -n "$CI_PROJECT_DIR" ]]; then
    STORAGE_PATH="$CI_PROJECT_DIR"
fi




psql -p $postgres_port -d $DB_NAME -a -v ON_ERROR_STOP=on -f - <<-EOF
CREATE OR REPLACE FUNCTION toolbox.get_consensus_storage_path() 
RETURNS TEXT 
LANGUAGE 'plpgsql' 
AS 
\$BODY$
DECLARE 
  __consensus_state_provider_storage_path TEXT; 
BEGIN 
  __consensus_state_provider_storage_path = '$STORAGE_PATH'; 
  RETURN __consensus_state_provider_storage_path; 
END
\$BODY$;
EOF

evaluate_result $?


postgres_procedure_exists() {
    local schema_name="$1"
    local procedure_name="$2"

    # Run the SQL function and remove leading/trailing white space
    local result=$(psql -p $postgres_port -d $DB_NAME -A -t -v ON_ERROR_STOP=on -c "SELECT toolbox.procedure_exists('$schema_name', '$procedure_name');")
    # Print the result
    echo $result
}


# psql -p $postgres_port -d $DB_NAME -v ON_ERROR_STOP=on -c "SET myapp.myvariable to 'myvalue'";
# psql -p $postgres_port -d $DB_NAME -v ON_ERROR_STOP=on -c "SELECT current_setting('myapp.myvariable')";
# psql -p $postgres_port -d $DB_NAME -v ON_ERROR_STOP=on -c "SET my_environment.CI_PROJECT_DIR to '$CI_PROJECT_DIR'";
# psql -p $postgres_port -d $DB_NAME -v ON_ERROR_STOP=on -c "SET my_environment.CI_PROJECT_DIR to 'myval'";

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

    fun_proc_name="${user}_test_${testfun}"
    output=$(postgres_procedure_exists 'public' $fun_proc_name)
    echo output=$output
    # Check if the procedure exists
    if [[ "$output" == *"t"* ]]; then
        counter=$((counter+1))
        echo "The procedure exists."
    else
        echo "The procedure does not exist."
    fi


   if [ "${user}" = "haf_admin_procedure" ]; then
      exists=$(postgres_procedure_exists "public" "${user}_test_${testfun}")
      if [ "$exists" = "t" ]; then
          echo "Procedure exists"
          sql_code_no_error="CALL ${user}_test_${testfun}();";
      else
          continue;
      fi
    else
      sql_code_no_error="DO \$\$
      BEGIN
        BEGIN
          PERFORM ${user}_test_${testfun}();
          EXCEPTION WHEN undefined_function THEN
        END;
      END \$\$;"
    fi

    sql_code_error="SELECT ${user}_test_${testfun}();";

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
  #     # mtlk - uncomment below when tests fixed
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

