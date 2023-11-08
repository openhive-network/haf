#! /bin/bash
# Test scenario
# 1. HAF is replayed to 1m of blocks and stops
# 2 HAF is started in the background to continue replay with limit 1.02m but now with huge psql-live-synch-threshold
# 3. a SQL HAF app is started to sync blocks in the background
#  it means hived is still replaying from blocklog file, but sql-serializer is syncing block in LIVE state
#  it give us dense calling context detaching, moving block one by one, and updating irreversible block
# 4. HAF app is stopped after syncin 1.02m of blocks
#
# Expected result
# 1. hived close and returns 0
# 2. hfm has synced 1.1m of blocks
# 3. HAF application close, returns 0 and has synced 1.02m of blocks

set -xeuo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

LOG_FILE=replay_with_update.log
source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"
NUMBER_OF_BLOCKS_TO_FIRST_REPLAY=1000000
LAST_BLOCK_TO_SYNC=$((${NUMBER_OF_BLOCKS_TO_FIRST_REPLAY}+20000));



test_start

# container must have /blockchain directory mounted containing block_log with at 5000000 first blocks
export BLOCK_LOG_SOURCE_DIR_5M="/blockchain/block_log_5m"
export PATTERNS_PATH="${REPO_DIR}/tests/integration/replay/patterns/no_filter"
export DATADIR="${REPO_DIR}/datadir"
export REPLAY="--replay-blockchain --stop-replay-at-block $NUMBER_OF_BLOCKS_TO_FIRST_REPLAY"
export REPLAY_CONTINUATION="--replay-blockchain --psql-livesync-threshold=1000000000 --stop-replay-at-block $LAST_BLOCK_TO_SYNC"
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

# 1. HAF is replayed to 1m of blocks and stops
echo -e "\e[0Ksection_start:$(date +%s):replay[collapsed=true]\r\e[0KExecuting replay..."
test -n "$PATTERNS_PATH"
mkdir $DATADIR/blockchain -p
cp "$PATTERNS_PATH"/* "$DATADIR" -r
cp ${BLOCK_LOG_SOURCE_DIR_5M}/block_log $DATADIR/blockchain
$HIVED_PATH --data-dir "$DATADIR" $REPLAY --exit-before-sync --psql-url "postgresql:///$DB_NAME" 2>&1 | tee -i node_logs.log
echo -e "\e[0Ksection_end:$(date +%s):replay\r\e[0K"

# 3 HAF is started to continue replay with limit 1.1m but now with huge psql-live-synch-threshold
$HIVED_PATH --data-dir "$DATADIR" $REPLAY_CONTINUATION --exit-before-sync --psql-url "postgresql:///$DB_NAME" 2>&1 | tee -i node_logs1.log &
hived_pid=$!
# 2. a SQL HAF app is started to sync blocks in the background
# run script that makes database update
psql -d $DB_NAME -a -v ON_ERROR_STOP=on -U $DB_ADMIN -f "${REPO_DIR}/tests/integration/replay/application.sql"

wait $hived_pid

test_end
