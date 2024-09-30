#! /bin/bash
# Test scenario
# This is a durability test which checks if syncing blocks
# works correctly when in parallel an application is processing.
# In the past HAF or application make violation of FK constraints when hived was processing
# new irreversible block events, and application attaching its contexts or finding a new event to process.
# test scenario:
# 1. HAF is replayed to 1m of blocks and stops
# 2. HAF is started in the background to continue replay with limit 1.02m but now with huge psql-live-sync-threshold
#   ad is restarted in a loop after each 3s
# 3. a SQL HAF app is started to sync blocks in the background
#  it means hived is still replaying from blocklog file, but sql-serializer is syncing block in LIVE state
#  it gives us dense calling context detaching, moving block one by one, and updating irreversible block
# 4. HAF app is stopped after syncing 1.02m of blocks, test is finished
#
# Expected results: hived and psql which runs the app returns with 0

set -xeuo pipefail

export HAF_SOURCE_DIR="/tmp/hafbuild"

sudo rm -rf /tmp/haf_data/datadir2/blockchain/shared_memory.bin
/tmp/hafbuild/scripts/setup_db.sh

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

LOG_FILE=replay_with_update.log
source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"
NUMBER_OF_BLOCKS_TO_FIRST_REPLAY=1000000
LAST_BLOCK_TO_SYNC=$((${NUMBER_OF_BLOCKS_TO_FIRST_REPLAY}+20000));



test_start

# container must have /blockchain directory mounted containing block_log with at 5000000 first blocks
export HIVED_PATH="/tmp/hafbuild/cmake-build-relwithdebinfo/hive/programs/hived/hived"
export DB_NAME="haf_block_log"
export REPO_DIR="/tmp/hafbuild"
export BLOCK_LOG_SOURCE_DIR_5M="/tmp/haf_data/blocks/block_log_5m/"
export PATTERNS_PATH="${REPO_DIR}/tests/integration/replay/patterns/no_filter"
export DATADIR="/tmp/haf_data/datadir2"
export REPLAY="--replay-blockchain --stop-replay-at-block $NUMBER_OF_BLOCKS_TO_FIRST_REPLAY --exit-after-replay"
export REPLAY_CONTINUATION="--replay-blockchain --psql-livesync-threshold=1000000000 --stop-replay-at-block $LAST_BLOCK_TO_SYNC"

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
$HIVED_PATH --data-dir "$DATADIR" $REPLAY --psql-url postgresql://hived:hived@localhost:5432/haf_block_log 2>&1 | tee -i node_logs.log
echo -e "\e[0Ksection_end:$(date +%s):replay\r\e[0K"


# 2. a SQL HAF app is started to sync blocks in the background
# run script that makes database update
(psql -d $DB_NAME -a -v ON_ERROR_STOP=on -U $DB_ADMIN -f "${REPO_DIR}/tests/integration/replay/application.sql" || kill -9 $PPID) &
app_pid=$!

# 3. HAF is started to continue replay with limit 1.1m but now with huge psql-live-sync-threshold

HEAD_BLOCK=1
get_head_block() {
  get_headblock_cmd=(psql -d ${DB_NAME} -v ON_ERROR_STOP=on -U ${DB_ADMIN} -t -c "SELECT num FROM hive.blocks_view ORDER BY num DESC LIMIT 1")
  HEAD_BLOCK=$("${get_headblock_cmd[@]}")
}
NUMBER_OF_RESTARTS=1
while true
do
  echo "HAF's hived continue"
  # to no restart
  #$HIVED_PATH --data-dir "$DATADIR" $REPLAY_CONTINUATION --psql-url postgresql://hived:hived@localhost:5432/haf_block_log 2>&1 #&
  #break
  # to restart:
    $HIVED_PATH --data-dir "$DATADIR" $REPLAY_CONTINUATION --psql-url postgresql://hived:hived@localhost:5432/haf_block_log 2>&1
    hived_pid=$!
     uncomment to get brak
    sleep 3
    echo "KILLING HAF's hived ${hived_pid}"
    kill -SIGINT $hived_pid
    wait $hived_pid
    hived_res=$?
    echo "KILLED HAF's hived ${hived_pid} with result ${hived_res}"
    if [ $hived_res -ne 0 ]
    then
      echo "HAF's hived process ${hived_res} crashed with result ${hived_res}"
      kill -SIGKKILL $app_pid
    fi

  NUMBER_OF_RESTARTS=$((NUMBER_OF_RESTARTS+1))
  get_head_block
  [ $HEAD_BLOCK -ge $LAST_BLOCK_TO_SYNC ] && break;

  jobs -l | grep $app_pid || break;
done

echo "HAF was restarted ${NUMBER_OF_RESTARTS} number of times and sync ${HEAD_BLOCK} blocks"
# the app must finish without errors
echo "If test will fail reaching this point, it means that the application crashed"
echo "Check the last occurrence of 'App is processing blocks' in the log"
wait $app_pid
app_result=$?
echo "The application has finished correctly"
echo "Test passed"

test_end
