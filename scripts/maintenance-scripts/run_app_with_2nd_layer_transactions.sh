#! /bin/bash
# Test scenario
# Synchronize HAFto 500k of blocks
# Then synchronize application example to 500k
# Verify the number of transactions counted by the app, the number depends on application commit/rollback functionalities

set -xeuo pipefail

sudo apt-get update
sudo apt-get install -y git

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

export LOG_FILE=replay_with_update.log
# shellcheck source=./ci_common.sh
source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"
NUMBER_OF_BLOCKS_TO_REPLAY=500000


test_start

# container must have /blockchain directory mounted containing block_log with at 500000 first blocks
export BLOCK_LOG_SOURCE_DIR_5M="/blockchain/block_log_5m"
export DATADIR="${REPO_DIR}/datadir"
export PATTERNS_PATH="${REPO_DIR}/tests/integration/replay/patterns/no_filter"
export REPLAY=("--replay-blockchain" "--exit-at-block=$NUMBER_OF_BLOCKS_TO_REPLAY")

if ! test -e "${BLOCK_LOG_SOURCE_DIR_5M}/block_log"
then
    echo "container must have /blockchain directory mounted containing block_log with at least 500000 first blocks"
    exit 1
fi

# 1. HAF is replayed
echo -e "\e[0Ksection_start:$(date +%s):replay[collapsed=true]\r\e[0KExecuting replay HAF..."
mkdir -p "$DATADIR/blockchain"
cp ${BLOCK_LOG_SOURCE_DIR_5M}/block_log "$DATADIR/blockchain"
cp -r "$PATTERNS_PATH"/* "$DATADIR"
$HIVED_PATH --data-dir "$DATADIR" "${REPLAY[@]}" --exit-before-sync --psql-url "postgresql:///$DB_NAME" 2>&1 | tee -i node_logs.log

echo -e "\e[0Ksection_end:$(date +%s):replay\r\e[0K"

echo -e "\e[0Ksection_start:$(date +%s):replay[collapsed=true]\r\e[0KExecuting application sync..."
# install application example
psql -d "$DB_NAME" -a -v ON_ERROR_STOP=on  -U "$DB_ADMIN" -f "${REPO_DIR}/src/hive_fork_manager/doc/examples/app_tx_rollback.sql"
# start syncing application
psql -d "$DB_NAME" -a -v ON_ERROR_STOP=on  -U "$DB_ADMIN" -c "CALL applications.run_histogram_app(500000)" 2>&1 | tee -i app_logs.log
echo -e "\e[0Ksection_end:$(date +%s):replay\r\e[0K"

# verify, there should be 48618 transaction counted, other number means that commit/rollback do not work
psql -d "$DB_NAME" -a -v ON_ERROR_STOP=on  -U "$DB_ADMIN" -c "DO \$\$ BEGIN ASSERT (SELECT SUM(trx) = 48618 FROM applications.trx_histogram), 'Expected tx number = 48618, rollback or commit does not work'; END \$\$ LANGUAGE plpgsql;"

test_end
