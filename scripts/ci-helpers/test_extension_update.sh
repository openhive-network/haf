#! /bin/bash

set -euo pipefail 

log_exec_params() {
  echo
  echo -n "$0 parameters: "
  for arg in "$@"; do echo -n "$arg "; done
  echo
}

log_exec_params "$@"

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Allows to specify required directories to run CI test"
    echo "OPTIONS:"
    echo "  --setup_scripts_path=NAME     "
    echo "  --haf_binaries_dir=NAME     "
    echo "  --ci_project_dir=NAME     "
    echo "  --help                    Display this help screen and exit"
    echo
}

SETUP_DIR=""
HAF_DIR=""
DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --setup_scripts_path=*)
        SETUP_DIR="${1#*=}"
        ;;
    --haf_binaries_dir=*)
        HAF_DIR="${1#*=}"
        ;;
    --ci_project_dir=*)
        DIR="${1#*=}"
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
        exit 2
        ;;
    esac
    shift
done


test_extension_update() {
    # modify the hived_api.sql file 
    echo -e "CREATE OR REPLACE FUNCTION hive.test() \n    RETURNS void \n    LANGUAGE plpgsql \n    VOLATILE AS \n\$BODY\$ \nBEGIN \nRAISE NOTICE 'test'; \nEND; \n\$BODY\$;" >> $DIR/src/hive_fork_manager/hived_api.sql
    # commit changes to make a new hash
    git -C $DIR config --global user.name "abc"
    git -C $DIR config --global user.email "abc@example.com"
    git -C $DIR config --global --add safe.directory /builds/hive/haf
    git -C $DIR add src/hive_fork_manager/hived_api.sql
    git -C $DIR commit -m "test"
    # rebuild haf
    $SETUP_DIR/build.sh --cmake-arg="-DHIVE_LINT=OFF" --haf-source-dir="$DIR" --haf-binaries-dir="$HAF_DIR" extension.hive_fork_manager
    (cd $HAF_DIR; sudo ninja install)
    # run generator script
    sudo /usr/share/postgresql/12/extension/hive_fork_manager_update_script_generator.sh
}

test_extension_update

