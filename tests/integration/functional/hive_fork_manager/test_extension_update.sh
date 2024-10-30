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
DB_ADMIN="haf_admin"
DB_NAME="haf_block_log"
POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432

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

    POSTGRES_VERSION=17
    echo "Add function testfun to schema hive"
    sudo -Enu "$DB_ADMIN" psql -d "$DB_NAME" -v ON_ERROR_STOP=on -U "$DB_ADMIN" -c "CREATE FUNCTION hive.testfun() RETURNS VOID AS \$\$ BEGIN END; \$\$ LANGUAGE plpgsql;"


    # old libhfm has to be removed so in case of an corrupted setup of haf the old libhfm won't be used
    sudo rm -rf /usr/lib/postgresql/${POSTGRES_VERSION}/lib/libhfm-*
    # modify the hived_api.sql file
    echo -e "CREATE OR REPLACE FUNCTION hive.test() \n    RETURNS void \n    LANGUAGE plpgsql \n    VOLATILE AS \n\$BODY\$ \nBEGIN \nRAISE NOTICE 'test'; \nEND; \n\$BODY\$;" >> $DIR/src/hive_fork_manager/hived_api.sql
    # commit changes to make a new hash
    git -C $DIR config --global user.name "abc"
    git -C $DIR config --global user.email "abc@example.com"
    git -C $DIR config --global --add safe.directory /builds/hive/haf
    git -C $DIR add src/hive_fork_manager/hived_api.sql
    git -C $DIR commit -m "test"
    # rebuild haf
    test -n "$HAF_DIR" && rm "$HAF_DIR"/* -rf
    $SETUP_DIR/build.sh --cmake-arg="-DHIVE_LINT=OFF" --haf-source-dir="$DIR" --haf-binaries-dir="$HAF_DIR" extension.hive_fork_manager
    (cd $HAF_DIR; sudo ninja install)
    # run generator script
    sudo /usr/share/postgresql/${POSTGRES_VERSION}/extension/hive_fork_manager_update_script_generator.sh

    # check if function test was removed (because entire hive schema was removed)
    sudo -Enu "$DB_ADMIN" psql -d "$DB_NAME" -v ON_ERROR_STOP=on -U "$DB_ADMIN" -c "
    DO \$\$
    BEGIN
        ASSERT NOT EXISTS (
            SELECT 1
            FROM pg_proc
            JOIN pg_namespace ON pg_proc.pronamespace = pg_namespace.oid
            WHERE pg_proc.proname = 'testfun'
            AND pg_namespace.nspname = 'hive'
        ), 'Function hive.testfun() exists when it should not.';
    END
    \$\$ LANGUAGE plpgsql;"


}

test_extension_update

