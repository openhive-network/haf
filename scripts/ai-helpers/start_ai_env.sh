#!/bin/bash

# Image variable, can be overridden by the environment
AI_ENV_IMAGE="${AI_ENV_IMAGE:-registry.gitlab.syncad.com/hive/haf/haf-builder:ubuntu24.04-8}"


BUILD_HAF() {
    echo "Building HAF..."
    docker exec ai_env sudo /tmp/haf/scripts/build.sh \
        --haf-source-dir=/tmp/haf \
        --haf-binaries-dir=/tmp/haf/build \
        --cmake-arg=-DBUILD_HIVE_TESTNET=OFF \
        --cmake-arg=-DENABLE_SMT_SUPPORT=OFF \
        --cmake-arg=-DHIVE_CONVERTER_BUILD=OFF \
        --cmake-arg=-DHIVE_LINT=OFF \
        --cmake-arg=-DPOSTGRES_PORT=5432

    echo "Installing HAF libraries..."
    docker exec ai_env sudo ninja -C /tmp/haf/build install
}

BUILD_HAF_TESTNET() {
    echo "Building HAF with TESTNET support..."
    docker exec ai_env sudo /tmp/haf/scripts/build.sh \
        --haf-source-dir=/tmp/haf \
        --haf-binaries-dir=/tmp/haf/build \
        --cmake-arg=-DBUILD_HIVE_TESTNET=ON \
        --cmake-arg=-DENABLE_SMT_SUPPORT=OFF \
        --cmake-arg=-DHIVE_CONVERTER_BUILD=OFF \
        --cmake-arg=-DHIVE_LINT=OFF \
        --cmake-arg=-DPOSTGRES_PORT=5432

    echo "Installing HAF libraries..."
    docker exec ai_env sudo ninja -C /tmp/haf/build install
}

CONFIGURE_POSTGRES() {
    echo "Configuring PostgreSQL..."
    # Create the custom data directory and config directory
    docker exec ai_env sudo mkdir -p /home/hived/datadir/haf_db_store/pgdata /home/hived/datadir/haf_postgresql_conf.d
    docker exec ai_env sudo chown -R postgres:postgres /home/hived
    docker exec ai_env sudo chown -R postgres:postgres /home/hived/datadir/haf_db_store/pgdata
    # Ensure parent directories are accessible (755) so other users (haf_admin) can traverse
    docker exec ai_env sudo chmod 755 /home/hived /home/hived/datadir /home/hived/datadir/haf_db_store


    # Initialize the database if it doesn't exist
    docker exec ai_env sudo -u postgres bash -c "[ -f /home/hived/datadir/haf_db_store/pgdata/PG_VERSION ] || /usr/lib/postgresql/17/bin/initdb -D /home/hived/datadir/haf_db_store/pgdata"

    docker exec ai_env sudo cp /tmp/haf/docker/postgresql.conf /etc/postgresql/17/main/postgresql.conf
    docker exec ai_env sudo cp /tmp/haf/docker/pg_hba.conf /etc/postgresql/17/main/pg_hba.conf
    # Add IPv4 localhost trust for system tests (not in production pg_hba.conf)
    docker exec ai_env sudo bash -c 'echo "host all all 127.0.0.1/32 trust" >> /etc/postgresql/17/main/pg_hba.conf'
    # Ensure correct ownership/permissions
    docker exec ai_env sudo chown postgres:postgres /etc/postgresql/17/main/postgresql.conf /etc/postgresql/17/main/pg_hba.conf

    echo "Restarting PostgreSQL..."
    docker exec ai_env sudo /etc/init.d/postgresql restart
}

START_CONTAINER() {
    echo "Starting ai_env container from image: $AI_ENV_IMAGE"
    # Start the container in detached mode, keeping it alive with sleep infinity
    docker run -d --name ai_env --entrypoint "" -v "$(pwd):/tmp/haf" -v "$(pwd)/datadir:/home/hived/datadir" "$AI_ENV_IMAGE" sleep infinity

    echo "Starting SSH service..."
    docker exec ai_env sudo /etc/init.d/ssh start
}

FIX_DATADIR_PERMISSIONS() {
    # Ensure parent directories are accessible (755) so other users (haf_admin) can traverse
    docker exec ai_env sudo chmod 755 /home/hived /home/hived/datadir /home/hived/datadir/haf_db_store 2>/dev/null || true
}

DO_RECOMPILE() {
    BUILD_HAF
}

DO_FUNCTIONAL_TEST() {
    # We do NOT build HAF here (user requested to skip specific build step).
    # We rely on previous build or ninja install handling dependencies.

    # Fix permissions to allow test user (haf_admin) to access PostgreSQL directories
    FIX_DATADIR_PERMISSIONS

    echo "Running functional test: $TEST_NAME"
    docker exec ai_env bash -c "cd /tmp/haf/build && ctest -j 10 -R $TEST_NAME $VERBOSE_OPT"
}

DO_SYSTEM_TEST() {
    # Run Python system tests using pytest
    # Uses venv + poetry like CI does (see scripts/maintenance-scripts/run_haf_system_tests.sh)

    FIX_DATADIR_PERMISSIONS

    echo "Setting up Python virtual environment (if needed)..."
    docker exec ai_env bash -c "
        if [ ! -d /tmp/haf/venv ]; then
            python3 -m venv --system-site-packages /tmp/haf/venv
            . /tmp/haf/venv/bin/activate
            python3 -m pip install pipx
            pipx install poetry
            (cd /tmp/haf/tests/integration/haf-local-tools && ~/.local/bin/poetry install)
        fi
    "

    echo "Running system test: $TEST_NAME"
    docker exec ai_env bash -c "
        . /tmp/haf/venv/bin/activate
        export PATH=~/.local/bin:\$PATH
        export HIVE_BUILD_ROOT_PATH=/tmp/haf/build/hive
        export DB_NAME=haf_block_log
        export DB_URL=\"postgresql://haf_admin@127.0.0.1:5432/\$DB_NAME\"
        export SETUP_SCRIPTS_PATH=/tmp/haf/scripts
        cd /tmp/haf/tests/integration/system/haf
        pytest $TEST_NAME $VERBOSE_OPT -s
    "
}

DO_INIT() {
    # Stop and remove the container if it already exists
    if [ "$(docker ps -aq -f name=^ai_env$)" ]; then
        echo "Removing existing ai_env container..."
        docker rm -f ai_env
    fi

    # Clean up data and build directories
    if [ -d "datadir" ]; then
        echo "Removing existing datadir..."
        # Use docker to remove to avoid permission issues with files owned by root/postgres in container
        docker run --rm -v "$(pwd):/work" ubuntu rm -rf /work/datadir
    fi

    if [ -d "build" ]; then
        echo "Removing existing build directory..."
        # Use docker to remove to avoid permission issues
        docker run --rm -v "$(pwd):/work" ubuntu rm -rf /work/build
    fi
    
    START_CONTAINER
    
    # Build HAF first so we can install the extension libraries
    BUILD_HAF

    CONFIGURE_POSTGRES
    
    echo "Creating haf_admin role and setting up database..."
    # Using setup_postgres.sh to create roles and superuser
    # Note: --install-extension=no as requested. 
    # --haf-database-store path inside container: /home/hived/datadir/haf_db_store
    # Using sudo to ensure permissions.
    docker exec ai_env sudo /tmp/haf/scripts/setup_postgres.sh --haf-binaries-dir="/tmp/haf/build" --haf-database-store="/home/hived/datadir/haf_db_store" --install-extension=no || echo "WARNING: setup_postgres.sh FAILED"
}

DO_INIT_TESTNET() {
    # Stop and remove the container if it already exists
    if [ "$(docker ps -aq -f name=^ai_env$)" ]; then
        echo "Removing existing ai_env container..."
        docker rm -f ai_env
    fi

    # Clean up data and build directories
    if [ -d "datadir" ]; then
        echo "Removing existing datadir..."
        docker run --rm -v "$(pwd):/work" ubuntu rm -rf /work/datadir
    fi

    if [ -d "build" ]; then
        echo "Removing existing build directory..."
        docker run --rm -v "$(pwd):/work" ubuntu rm -rf /work/build
    fi

    START_CONTAINER

    # Build HAF with testnet support for system tests
    BUILD_HAF_TESTNET

    CONFIGURE_POSTGRES

    echo "Creating haf_admin role and setting up database..."
    docker exec ai_env sudo /tmp/haf/scripts/setup_postgres.sh --haf-binaries-dir="/tmp/haf/build" --haf-database-store="/home/hived/datadir/haf_db_store" --install-extension=no || echo "WARNING: setup_postgres.sh FAILED"

    # Create haf_block_log template database for system tests
    echo "Creating haf_block_log template database..."
    docker exec ai_env sudo -u postgres psql -c "CREATE DATABASE haf_block_log OWNER haf_admin;"
    docker exec ai_env sudo -u postgres psql -d haf_block_log -c "CREATE EXTENSION IF NOT EXISTS hive_fork_manager CASCADE;"
}

DO_DEFAULT() {
    # If container doesn't exist, start it (for default case without --init)
    if [ ! "$(docker ps -q -f name=^ai_env$)" ]; then
        START_CONTAINER
        CONFIGURE_POSTGRES
    fi
    echo "Restarting PostgreSQL..."
    docker exec ai_env sudo /etc/init.d/postgresql restart
    BUILD_HAF
}

# Parse arguments
OPTION="default"
TEST_NAME="test.functional.hive_fork_manager"
VERBOSE_OPT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --init)
        OPTION="init"
        ;;
    --init-testnet)
        OPTION="init_testnet"
        ;;
    --recompile)
        OPTION="recompile"
        ;;
    --functional-test)
        OPTION="functional_test"
        if [ -n "$2" ] && [[ ! "$2" =~ ^- ]]; then
            TEST_NAME="$2"
            shift
        fi
        ;;
    --system-test)
        OPTION="system_test"
        TEST_NAME=""  # Default: run all tests in directory
        if [ -n "$2" ] && [[ ! "$2" =~ ^- ]]; then
            TEST_NAME="$2"
            shift
        fi
        ;;
    --verbose)
        VERBOSE_OPT="--verbose"
        ;;
    --help)
        echo "Usage: $0 [OPTION]..."
        echo
        echo "Manages the HAF Docker development environment (AI_ENV)."
        echo "This script automates the lifecycle of the Docker container, PostgreSQL configuration, and HAF build process."
        echo
        echo "OPTIONS:"
        echo "  --init"
        echo "      PURPOSE: Full environment reset and initialization."
        echo "      ACTIONS:"
        echo "        1. [HOST]   Removes existing 'ai_env' container (docker rm -f)."
        echo "        2. [HOST]   Deletes 'datadir' and 'build' directories (sudo rm -rf)."
        echo "        3. [DOCKER] Starts 'ai_env' container with volume mounts."
        echo "        4. [DOCKER] Builds and installs HAF (cmake/ninja + ninja install)."
        echo "        5. [DOCKER] Configures PostgreSQL (initdb, postgresql.conf copy, start)."
        echo "        6. [DOCKER] Runs 'setup_postgres.sh' to create roles (haf_admin) and DB."
        echo "      SIDE EFFECTS: destructive to data/build artifacts. Requires pseudo-tty/sudo for cleanup."
        echo
        echo "  --init-testnet"
        echo "      PURPOSE: Full environment reset with TESTNET build (for system tests)."
        echo "      ACTIONS:"
        echo "        1-3. Same as --init"
        echo "        4. [DOCKER] Builds HAF with BUILD_HIVE_TESTNET=ON."
        echo "        5-6. Same as --init"
        echo "        7. [DOCKER] Creates haf_block_log template database with HAF extension."
        echo "      USE CASE: Required for running system tests that need testnet hived."
        echo
        echo "  --recompile"
        echo "      PURPOSE: Incremental build of HAF source code."
        echo "      ACTIONS:"
        echo "        1. [DOCKER] Runs 'scripts/build.sh' (ninja)."
        echo "        2. [DOCKER] Installs HAF libraries (ninja install) to PostgreSQL."
        echo "      SIDE EFFECTS: Update binaries in 'build' directory. No container restart."
        echo
        echo "  --functional-test [TEST_NAME]"
        echo "      PURPOSE: Run regression/functional tests."
        echo "      ACTIONS:"
        echo "        1. [DOCKER] Fixes directory permissions for test access."
        echo "        2. [DOCKER] Executes 'ctest -R TEST_NAME'."
        echo "      ARGUMENTS:"
        echo "        TEST_NAME: Regex for ctest (Optional, default: 'test.functional.hive_fork_manager')."
        echo "      DEPENDENCIES:"
        echo "        Requires running container 'ai_env'. PostgreSQL must be running with HAF extension installed."
        echo "      NOTE: Does NOT rebuild HAF. Use --recompile first if code changed."
        echo
        echo "  --system-test [TEST_NAME]"
        echo "      PURPOSE: Run Python system tests using pytest."
        echo "      ACTIONS:"
        echo "        1. [DOCKER] Fixes directory permissions for test access."
        echo "        2. [DOCKER] Executes 'pytest TEST_NAME' in system/haf directory."
        echo "      ARGUMENTS:"
        echo "        TEST_NAME: Test file or pattern (Optional, e.g., 'test_live_sync_from_115.py')."
        echo "                   If omitted, runs all tests in the directory."
        echo "      DEPENDENCIES:"
        echo "        Requires running container 'ai_env'. Requires hived binary built with BUILD_HIVE_TESTNET=ON."
        echo "      EXAMPLES:"
        echo "        ./start_ai_env.sh --system-test test_live_sync.py"
        echo "        ./start_ai_env.sh --system-test test_live_sync_from_115.py::test_live_sync_from_115"
        echo "      NOTE: Does NOT rebuild HAF. Use --recompile first if code changed."
        echo
        echo "  --verbose"
        echo "      PURPOSE: Increase verbosity of tests."
        echo "      CONTEXT: Use with --functional-test or --system-test."
        echo "               For functional tests: adds '--verbose' to ctest."
        echo "               For system tests: adds '--verbose' to pytest."
        echo
        echo "  (Default/No Option)"
        echo "      PURPOSE: Ensure environment is running and built."
        echo "      ACTIONS:"
        echo "        1. [DOCKER] Starts 'ai_env' if missing."
        echo "        2. [DOCKER] Configures PostgreSQL (if fresh start)."
        echo "        3. [DOCKER] Builds HAF."
        echo
        echo "AI AGENT CONTEXT:"
        echo "  - Container Name: ai_env"
        echo "  - Image: Registry image (see script variable AI_ENV_IMAGE)"
        echo "  - Volume Mounts: CWD -> /tmp/haf; ./datadir -> /home/hived/datadir"
        echo "  - Postgres Port: 5432 (inside container)"
        echo "  - Build Dir: /tmp/haf/build (inside container), ./build (host)"
        echo "  - Roles Created: haf_admin, hived_group, hive_applications_group"
        echo
        exit 0
        ;;
    -*)
        echo "Unknown option: $1"
        exit 1
        ;;
    *)
        # Handle positional arguments
        if [ "$OPTION" = "functional_test" ]; then
            TEST_NAME="$1"
        else
            echo "Unknown argument: $1"
            exit 1
        fi
        ;;
    esac
    shift
done

case "$OPTION" in
    "recompile")
        DO_RECOMPILE
        ;;
    "functional_test")
        DO_FUNCTIONAL_TEST
        ;;
    "system_test")
        DO_SYSTEM_TEST
        ;;
    "init")
        DO_INIT
        ;;
    "init_testnet")
        DO_INIT_TESTNET
        ;;
    "default")
        DO_DEFAULT
        ;;
esac

