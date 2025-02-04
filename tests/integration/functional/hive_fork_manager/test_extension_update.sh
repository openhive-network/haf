#! /bin/bash -x

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
export POSTGRES_HOST="/var/run/postgresql"
export POSTGRES_PORT=5432

while [ $# -gt 0 ]; do
  case "$1" in
    --setup_scripts_path=*)
        SETUP_DIR="${1#*=}"
        export SETUP_DIR
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
    # copy sources to build directory, they will be modified there to create real new version of hfm extension
    COPY_SRC_PATH="${HAF_DIR}/src_copy"
    COPY_BUILD_PATH="${HAF_DIR}/src_copy/build"
    rm -rf "${COPY_SRC_PATH}"
    mkdir -p "${COPY_SRC_PATH}"
    mkdir -p "${COPY_BUILD_PATH}"
    cp -a "${DIR}/." "${COPY_SRC_PATH}"

    POSTGRES_VERSION=17
    echo "Add function testfun to schema hive"
    sudo -Enu "$DB_ADMIN" psql -d "$DB_NAME" -v ON_ERROR_STOP=on -U "$DB_ADMIN" -c "CREATE FUNCTION hive.testfun() RETURNS VOID AS \$\$ BEGIN END; \$\$ LANGUAGE plpgsql;"


    # old libhfm has to be removed so in case of an corrupted setup of haf the old libhfm won't be used
    sudo rm -rf /usr/lib/postgresql/${POSTGRES_VERSION}/lib/libhfm-*
    # modify the hived_api.sql file, new function test added to the new version of hfm
    echo -e "CREATE OR REPLACE FUNCTION hive.test() \n    RETURNS void \n    LANGUAGE plpgsql \n    VOLATILE AS \n\$BODY\$ \nBEGIN \nRAISE NOTICE 'test'; \nEND; \n\$BODY\$;" >> "${COPY_SRC_PATH}/src/hive_fork_manager/hived_api.sql"
    # commit changes to make a new hash
    git -C "${COPY_BUILD_PATH}" config --global user.name "abc"
    git -C "${COPY_BUILD_PATH}" config --global user.email "abc@example.com"
    git -C "${COPY_BUILD_PATH}" config --global --add safe.directory /builds/hive/haf
    git -C "${COPY_BUILD_PATH}" add "${COPY_SRC_PATH}/src/hive_fork_manager/hived_api.sql"
    git -C "${COPY_BUILD_PATH}" commit -m "test"
    # rebuild copy of haf
    "${COPY_SRC_PATH}/scripts/build.sh" --cmake-arg="-DHIVE_LINT=OFF" --haf-source-dir="${COPY_SRC_PATH}" --haf-binaries-dir="${COPY_BUILD_PATH}" extension.hive_fork_manager
    (cd "${COPY_BUILD_PATH}" || exit 1; sudo ninja install)
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

    # check if function test added in new hfm version exists
    sudo -Enu "$DB_ADMIN" psql -d "$DB_NAME" -v ON_ERROR_STOP=on -U "$DB_ADMIN" -c "
    DO \$\$
    BEGIN
        ASSERT EXISTS (
            SELECT 1
            FROM pg_proc
            JOIN pg_namespace ON pg_proc.pronamespace = pg_namespace.oid
            WHERE pg_proc.proname = 'test'
            AND pg_namespace.nspname = 'hive'
        ), 'Function hive.test() not exists when it should not.';
    END
    \$\$ LANGUAGE plpgsql;"
}

test_extension_update

