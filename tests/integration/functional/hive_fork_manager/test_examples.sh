#!/usr/bin/env bash

examples_folder="$1"
test_path="$2"
setup_scripts_dir_path="$3"
postgres_port="$4"

# shellcheck source=/dev/null
. ./tools/common.sh

setup_test_database "$setup_scripts_dir_path" "$postgres_port" "$test_path"

psql -U haf_admin -p "$postgres_port" -d "$DB_NAME" -a -v ON_ERROR_STOP=on -f  ./tools/test_tools.sql;

psql -U haf_admin -p "${postgres_port}" -d "${DB_NAME}" -a -v ON_ERROR_STOP=on -f "./tools/mocks.sql"
evaluate_result $?;

psql -U haf_admin -p "${postgres_port}" -d "${DB_NAME}" -a -v ON_ERROR_STOP=on -f ./hive_fork_manager/examples/prepare_data.sql
evaluate_result $?;

test_name=$(test_name_from_path "$test_path")

python3 -m venv ".test_examples_$test_name"
# shellcheck source=/dev/null
. "./.test_examples_$test_name/bin/activate"

# HAF_EXAMPLES_WHEELS: a directory of wheels to install the dependencies from
# without a package index (.aidev/hfm-functional.sh sets it)
if [ -n "${HAF_EXAMPLES_WHEELS:-}" ]; then
  python3 -mpip install --no-index --find-links "$HAF_EXAMPLES_WHEELS" -r ./hive_fork_manager/examples/requirements.txt
else
  python3 -mpip install --upgrade pip

  python3 -mpip install wheel==0.41.2

  python3 -mpip install -r ./hive_fork_manager/examples/requirements.txt
fi

( "$test_path" "$examples_folder" "$DB_NAME" "$postgres_port" )

evaluate_result $?;

psql -U haf_admin -p "$postgres_port" -d postgres -v ON_ERROR_STOP=on -c "DROP DATABASE $DB_NAME";

exit 0
