#! /bin/bash
# Test scenario
# The primary purpose of this test is to verify the functionality of pruned replay.
# It ensures that pruning while replaying blocks works correctly and does not result in violations
# of foreign key constraints or other database inconsistencies.
# Specifically, the test checks if syncing blocks works correctly when an application processes data
# in parallel with pruning-induced context detachment and block updates.
# test scenario:
# 1. HAF is replayed (from block log) to 1000000 of blocks and stops, together with an application
# Expected results: hived and psql which runs the app returns with 0, there should be less than 1k of block in the db

set -xeuo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

export LOG_FILE=replay_with_update.log
# shellcheck source=./ci_common.sh
source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"
NUMBER_OF_BLOCKS_TO_REPLAY=1000

test_start

# container must have /blockchain directory mounted containing block_log with at 5000000 first blocks
export BLOCK_LOG_SOURCE_DIR_5M="/blockchain/block_log_1m"
export PATTERNS_PATH="${REPO_DIR}/tests/integration/replay/patterns/no_filter"
export DATADIR="${REPO_DIR}/datadir"
export INIT_DB=("--replay-blockchain" "--psql-prune-blocks=10" "--exit-at-block=1")
export REPLAY=("--replay-blockchain" "--psql-prune-blocks=10" "--exit-at-block=$NUMBER_OF_BLOCKS_TO_REPLAY")

if ! test -e "${BLOCK_LOG_SOURCE_DIR_5M}/block_log"
then
    echo "container must have /blockchain directory mounted containing block_log with at least 5000000 first blocks"
    exit 1
fi

# 1. HAF is replayed to 1m of blocks and stops
echo -e "\e[0Ksection_start:$(date +%s):replay[collapsed=true]\r\e[0KExecuting replay..."
test -n "$PATTERNS_PATH"
mkdir -p "$DATADIR/blockchain"
cp -r "$PATTERNS_PATH"/* "$DATADIR"
cp ${BLOCK_LOG_SOURCE_DIR_5M}/block_log "$DATADIR/blockchain"
# workaround for issue haf#302: initialize db with first replay
$HIVED_PATH --data-dir "$DATADIR" "${INIT_DB[@]}" --exit-before-sync --psql-url "postgresql:///$DB_NAME" 2>&1 | tee -i node_logs.log
$HIVED_PATH --data-dir "$DATADIR" "${REPLAY[@]}" --exit-before-sync --psql-url "postgresql:///$DB_NAME" 2>&1 | tee -i node_logs.log &
hived_pid=$!


psql -d "$DB_NAME" -a -v ON_ERROR_STOP=on -v LAST_BLOCK="${NUMBER_OF_BLOCKS_TO_REPLAY}" -U "$DB_ADMIN" -f "${REPO_DIR}/tests/integration/replay/application.sql"
echo -e "\e[0Ksection_end:$(date +%s):replay\r\e[0K"

wait $hived_pid

# Verify that block data has been removed.
# Because pruning is triggered asynchronously (the app is not synchronized with hived),
# perform a rough check that fewer than 100000 blocks remain (without pruning there would be about 1000000).
psql -d "$DB_NAME" -a -v ON_ERROR_STOP=on  -U "$DB_ADMIN" -c "DO \$\$ BEGIN ASSERT (SELECT COUNT(*) < 100000 FROM hafd.blocks), 'Expected < 100000 rows in hafd.blocks'; END \$\$ LANGUAGE plpgsql;"

test_end
