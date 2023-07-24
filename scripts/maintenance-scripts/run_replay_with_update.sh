#! /bin/bash
set -xeuo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

LOG_FILE=replay_with_update.log
source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"


test_start

# container must have /blockchain directory mounted containing block_log with at 5000000 first blocks
export BLOCK_LOG_SOURCE_DIR_5M="/blockchain/block_log_5m"
export PATTERNS_PATH="${REPO_DIR}/tests/integration/replay/patterns/no_filter"
export DATADIR="${REPO_DIR}/datadir"
export REPLAY="--replay-blockchain --stop-replay-at-block 1000000"
export REPLAY_CONTINUATION="--replay-blockchain --stop-replay-at-block 2000000"
export HIVED_PATH="/home/hived/bin/hived"
export COMPRESS_BLOCK_LOG_PATH="/home/hived/bin/compress_block_log"
export DB_NAME=haf_block_log
export DB_ADMIN="haf_admin"
export SETUP_SCRIPTS_PATH="/home/haf_admin/haf/scripts"

if ! test -e "${BLOCK_LOG_SOURCE_DIR_5M}/block_log"
then
    echo "container must have /blockchain directory mounted containing block_log with at least 5000000 first blocks"
    exit 1
fi

echo -e "\e[0Ksection_start:$(date +%s):replay[collapsed=true]\r\e[0KExecuting replay..."
test -n "$PATTERNS_PATH"
mkdir $DATADIR/blockchain -p
cp "$PATTERNS_PATH"/* "$DATADIR" -r
cp ${BLOCK_LOG_SOURCE_DIR_5M}/block_log $DATADIR/blockchain
$HIVED_PATH --data-dir "$DATADIR" $REPLAY --exit-before-sync --psql-url "postgresql:///$DB_NAME" 2>&1 | tee -i node_logs.log
echo -e "\e[0Ksection_end:$(date +%s):replay\r\e[0K"

# run script that makes database update
"${REPO_DIR}/tests/integration/functional/hive_fork_manager/test_extension_update.sh" \
    --setup_scripts_path="$SETUP_SCRIPTS_PATH" --haf_binaries_dir="/home/haf_admin/build" --ci_project_dir="$REPO_DIR"

# repeat replay from 1 milion blocks
$HIVED_PATH --data-dir "$DATADIR" $REPLAY_CONTINUATION --exit-before-sync --psql-url "postgresql:///$DB_NAME" 2>&1 | tee -i node_logs1.log

# verify if upgrade is complete by calling the new added function
psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "SELECT hive.test()"

test_end
