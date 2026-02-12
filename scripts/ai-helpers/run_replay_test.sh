#!/bin/bash

# Script to run HAF replay tests locally, mimicking CI environment.
# Uses the HAF Docker image with docker_entrypoint.sh like CI does.

set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
HAF_DIR="$(cd "$SCRIPTPATH/../.." && pwd)"

# Default configuration - use local image if available
HAF_IMAGE="${HAF_IMAGE:-registry.gitlab.syncad.com/hive/haf:local}"
BLOCK_LOG_DIR="${BLOCK_LOG_SOURCE_DIR_5M:-/storage_nvme/blocks/block_log_5m}"
CONTAINER_NAME="haf_replay_test"

print_help() {
    echo "Usage: $0 <TEST_NAME> [OPTIONS]"
    echo
    echo "Run HAF replay tests locally using the HAF Docker image."
    echo "This script mimics the CI environment by using docker_entrypoint.sh."
    echo
    echo "AVAILABLE TESTS (maintenance scripts):"
    echo "  replay_with_update          - Test extension update during replay"
    echo "  replay_with_app             - Replay with application (live sync)"
    echo "  replay_with_breaks          - Replay with interruptions"
    echo "  replay_live_pruned          - Live pruned replay with app"
    echo "  replay_reindex_pruned       - Reindex pruned replay with app"
    echo "  replay_with_restarts        - Live replay with restarts"
    echo "  replay_with_keyauth         - Replay with keyauth state provider"
    echo "  hfm_functional_tests        - HAF Fork Manager functional tests"
    echo
    echo "OPTIONS:"
    echo "  --block-log=PATH    Path to block_log directory (default: /storage_nvme/blocks/block_log_5m)"
    echo "  --image=IMAGE       HAF Docker image to use (default: registry.gitlab.syncad.com/hive/haf:local)"
    echo "  --keep              Keep container after test (for debugging)"
    echo "  --help              Show this help"
    echo
    echo "EXAMPLES:"
    echo "  $0 replay_with_update"
    echo "  $0 replay_with_app --block-log=/path/to/blocklog"
    echo "  $0 replay_with_update --keep"
    echo
    echo "ENVIRONMENT VARIABLES:"
    echo "  HAF_IMAGE                 - Override default HAF image"
    echo "  BLOCK_LOG_SOURCE_DIR_5M   - Override default block log path"
    echo
}

# Map test names to maintenance scripts
get_maintenance_script() {
    local test_name="$1"
    case "$test_name" in
        replay_with_update)
            echo "run_replay_with_update.sh"
            ;;
        replay_with_app)
            echo "run_live_replay_with_app.sh"
            ;;
        replay_with_breaks)
            echo "run_replay_with_breaks.sh"
            ;;
        replay_live_pruned)
            echo "run_live_pruned_replay_with_app.sh"
            ;;
        replay_reindex_pruned)
            echo "run_reindex_pruned_replay_with_app.sh"
            ;;
        replay_with_restarts)
            echo "run_live_replay_with_restarts_and_app.sh"
            ;;
        replay_with_keyauth)
            echo "state_provider:run_replay_with_keyauth.sh"
            ;;
        hfm_functional_tests)
            echo "run_hfm_functional_tests.sh"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Parse arguments
TEST_NAME=""
KEEP_CONTAINER=0

while [ $# -gt 0 ]; do
    case "$1" in
        --block-log=*)
            BLOCK_LOG_DIR="${1#*=}"
            ;;
        --image=*)
            HAF_IMAGE="${1#*=}"
            ;;
        --keep)
            KEEP_CONTAINER=1
            ;;
        --help|-h)
            print_help
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            print_help
            exit 1
            ;;
        *)
            if [ -z "$TEST_NAME" ]; then
                TEST_NAME="$1"
            else
                echo "Error: Multiple test names specified"
                print_help
                exit 1
            fi
            ;;
    esac
    shift
done

if [ -z "$TEST_NAME" ]; then
    echo "Error: No test name specified"
    print_help
    exit 1
fi

MAINTENANCE_SCRIPT=$(get_maintenance_script "$TEST_NAME")
if [ -z "$MAINTENANCE_SCRIPT" ]; then
    echo "Error: Unknown test name: $TEST_NAME"
    echo "Run '$0 --help' for available tests"
    exit 1
fi

# Verify block log exists
if [ ! -f "${BLOCK_LOG_DIR}/block_log" ]; then
    echo "Error: Block log not found at ${BLOCK_LOG_DIR}/block_log"
    echo "Use --block-log=PATH to specify location"
    exit 1
fi

echo "=== HAF Replay Test ==="
echo "Test:       $TEST_NAME"
echo "Script:     $MAINTENANCE_SCRIPT"
echo "Image:      $HAF_IMAGE"
echo "Block log:  $BLOCK_LOG_DIR"
echo "HAF source: $HAF_DIR"
echo "========================"

# Cleanup function
cleanup() {
    if [ "$KEEP_CONTAINER" -eq 0 ]; then
        echo "Cleaning up container..."
        docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    else
        echo "Container kept for debugging: $CONTAINER_NAME"
        echo "To access: docker exec -it $CONTAINER_NAME bash"
        echo "To remove: docker rm -f $CONTAINER_NAME"
    fi
}

# Remove existing container
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Set up trap for cleanup
if [ "$KEEP_CONTAINER" -eq 0 ]; then
    trap cleanup EXIT
fi

echo "Starting HAF container..."

# Clean up previous test artifacts (test creates datadir/ and log files in source dir)
# Note: Previous runs may have created files owned by container users (root, postgres)
# so we use docker to clean them up with proper permissions
echo "Cleaning up previous test artifacts..."
# Clean directories that might have been created by previous container runs
for dir in datadir datadir_replay database; do
    if [ -d "${HAF_DIR}/${dir}" ]; then
        echo "  Removing ${dir}..."
        docker run --rm -v "${HAF_DIR}:/work" ubuntu rm -rf "/work/${dir}" 2>/dev/null || rm -rf "${HAF_DIR}/${dir}" 2>/dev/null || true
    fi
done

# Clean build directory completely - it contains Makefiles with hardcoded paths
# This is needed because test_extension_update.sh copies the source including build/
# and the generated files reference ai_env paths (/tmp/haf) not container paths
if [ -d "${HAF_DIR}/build" ]; then
    echo "  Removing build directory (contains ai_env path references)..."
    docker run --rm -v "${HAF_DIR}:/work" ubuntu rm -rf /work/build 2>/dev/null || rm -rf "${HAF_DIR}/build" 2>/dev/null || true
    echo "  WARNING: ai_env build directory was removed. Run 'start_ai_env.sh --recompile' to rebuild if needed."
fi
rm -f "${HAF_DIR}/replay_with_update.log" "${HAF_DIR}/node_logs.log" "${HAF_DIR}/node_logs1.log" 2>/dev/null || true

# Create test directories with proper permissions for container access
# Container runs as haf_admin (UID 4000) which doesn't match host UID
# Create directories that will be written to and make them world-writable
echo "Setting up test directories with proper permissions..."
mkdir -p "${HAF_DIR}/datadir/blockchain"
chmod -R 777 "${HAF_DIR}/datadir"
# Create file placeholders that can be written by container
# Log files:
touch "${HAF_DIR}/replay_with_update.log" "${HAF_DIR}/node_logs.log" "${HAF_DIR}/node_logs1.log"
chmod 666 "${HAF_DIR}/replay_with_update.log" "${HAF_DIR}/node_logs.log" "${HAF_DIR}/node_logs1.log"
# Extension update script comparison files (written by hive_fork_manager_update_script_generator.sh):
touch "${HAF_DIR}/before_update_columns.txt" "${HAF_DIR}/before_update_constraints.txt" "${HAF_DIR}/before_update_indexes.txt" "${HAF_DIR}/before_update_providers.txt"
# Note: the script has a typo "constraings" instead of "constraints" for after_update_*
touch "${HAF_DIR}/after_update_columns.txt" "${HAF_DIR}/after_update_constraints.txt" "${HAF_DIR}/after_update_constraings.txt" "${HAF_DIR}/after_update_indexes.txt" "${HAF_DIR}/after_update_providers.txt"
chmod 666 "${HAF_DIR}"/*_update_*.txt 2>/dev/null || true

# Make source directory and its contents readable by container (UID 4000)
# This is needed because test_extension_update.sh copies the source for testing
echo "Making source readable for container..."
chmod -R a+rX "${HAF_DIR}" 2>/dev/null || true

# Make tests/integration/functional writable for virtual environment creation
echo "Making test directory writable for container..."
chmod -R a+rwX "${HAF_DIR}/tests/integration/functional" 2>/dev/null || true

# Determine the script path based on prefix
if [[ "$MAINTENANCE_SCRIPT" == state_provider:* ]]; then
    SCRIPT_NAME="${MAINTENANCE_SCRIPT#state_provider:}"
    SCRIPT_PATH="/home/haf_admin/source/tests/integration/state_provider/${SCRIPT_NAME}"
else
    SCRIPT_PATH="/home/haf_admin/source/scripts/maintenance-scripts/${MAINTENANCE_SCRIPT}"
fi

# Run the container with the maintenance script
# Mount:
#   - HAF source at /home/haf_admin/source (read-write for test artifacts)
#   - Block log at /blockchain/block_log_5m (read-only)
#   - Datadir for PostgreSQL data at /home/hived/datadir
# Note: Source must be read-write because maintenance scripts create datadir/ and log files there
docker run --name "$CONTAINER_NAME" \
    -v "${HAF_DIR}:/home/haf_admin/source" \
    -v "${BLOCK_LOG_DIR}:/blockchain/block_log_5m:ro" \
    -e "HIVE_SUBDIR=" \
    -e "DATADIR=/home/hived/datadir" \
    -e "SHM_DIR=/home/hived/datadir/blockchain" \
    -e "WAL_DIR=/home/hived/datadir" \
    -e "PG_ACCESS=local all all trust" \
    -e "CI_PROJECT_DIR=/home/haf_admin/source" \
    -e "BLOCK_LOG_SOURCE_DIR_5M=/blockchain/block_log_5m" \
    -e "DB_NAME=haf_block_log" \
    -e "DB_ADMIN=haf_admin" \
    -e "HIVED_PATH=/home/hived/bin/hived" \
    "$HAF_IMAGE" \
    --execute-maintenance-script="${SCRIPT_PATH}"

echo ""
echo "=== Test completed ==="
