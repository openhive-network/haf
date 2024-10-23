#! /bin/bash
# Test scenario
# This is a durability test which checks if syncing blocks
# works correctly when during replay the hived is broken with SIG_INT
# In the past sometimes HAF could not restart after break because of irreversible data inconsistency
# test scenario:
# 1. HAF is replayed to 100 of blocks and stops, thus to be sure that hafd.blocks has some content
# 2. HAF is started in the background to continue replay with limit 3m but now with huge psql-live-sync-threshold
#   ad is restarted in a loop after each 3s
# 4. HAF app is stopped after syncing 3m of blocks, test is finished
#
# Expected results: hived and psql which runs the app returns with 0

set -xeuo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

LOG_FILE=replay_with_update.log
source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"
NUMBER_OF_BLOCKS_TO_FIRST_REPLAY=100
LAST_BLOCK_TO_SYNC=3000000;



test_start

# container must have /blockchain directory mounted containing block_log with at 5000000 first blocks
export BLOCK_LOG_SOURCE_DIR_5M="/blockchain/block_log_5m"
export PATTERNS_PATH="${REPO_DIR}/tests/integration/replay/patterns/no_filter"
export DATADIR="${REPO_DIR}/datadir"
export REPLAY="--replay-blockchain --stop-at-block $NUMBER_OF_BLOCKS_TO_FIRST_REPLAY --exit-before-sync"
export REPLAY_CONTINUATION="--replay-blockchain --stop-at-block $LAST_BLOCK_TO_SYNC"

if ! test -e "${BLOCK_LOG_SOURCE_DIR_5M}/block_log"
then
    echo "container must have /blockchain directory mounted containing block_log with at least 5000000 first blocks"
    exit 1
fi

# 1. HAF is replayed to 100 of blocks and stops
echo -e "\e[0Ksection_start:$(date +%s):replay[collapsed=true]\r\e[0KExecuting replay..."
test -n "$PATTERNS_PATH"
mkdir $DATADIR/blockchain -p
cp "$PATTERNS_PATH"/* "$DATADIR" -r
cp ${BLOCK_LOG_SOURCE_DIR_5M}/block_log $DATADIR/blockchain
$HIVED_PATH --data-dir "$DATADIR" $REPLAY --psql-url "postgresql:///$DB_NAME" 2>&1 | tee -i node_logs.log
echo -e "\e[0Ksection_end:$(date +%s):replay\r\e[0K"


# 2. HAF is started to continue replay with limit 1.1m but now with huge psql-live-sync-threshold

HEAD_BLOCK=1
get_head_block() {
  get_headblock_cmd=(psql -d ${DB_NAME} -v ON_ERROR_STOP=on -U ${DB_ADMIN} -t -c "SELECT num FROM hive.blocks_view ORDER BY num DESC LIMIT 1")
  HEAD_BLOCK=$("${get_headblock_cmd[@]}")
}
NUMBER_OF_RESTARTS=1
while true
do
  echo "HAF's hived continue"
  $HIVED_PATH --data-dir "$DATADIR" $REPLAY_CONTINUATION --psql-url "postgresql:///$DB_NAME" 2>&1 &
  hived_pid=$!
  sleep 2
  echo "KILLING HAF's hived ${hived_pid}"
  kill -SIGINT $hived_pid
  wait $hived_pid
  hived_res=$?
  echo "KILLED HAF's hived ${hived_pid} with result ${hived_res}"


  if [ $hived_res -ne 0 ]
  then
    echo "HAF's hived process ${hived_res} crashed with result ${hived_res}"
  fi

  NUMBER_OF_RESTARTS=$((NUMBER_OF_RESTARTS+1))
  get_head_block
  [ $HEAD_BLOCK -ge $LAST_BLOCK_TO_SYNC ] && break;
done

echo "HAF was restarted ${NUMBER_OF_RESTARTS} number of times and sync ${HEAD_BLOCK} blocks"

echo "Test passed"

test_end
