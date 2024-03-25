#! /bin/bash


set -euo pipefail

SCRIPTPATH="$CI_PROJECT_DIR/tests/integration/state_provider"
SCRIPTSDIR="$CI_PROJECT_DIR/scripts"
LOG_FILE=replay_with_json_metadata.log

source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"

test_start

# container must have /blockchain directory mounted containing block_log with at 5000000 first blocks
export REPO_DIR="${SCRIPTDIR}/../"
export BLOCK_LOG_SOURCE_DIR_5M="/blockchain/block_log_5m"
export DATADIR="${REPO_DIR}/datadir"
export REPLAY="--replay-blockchain --stop-replay-at-block 5000000"
export HIVED_PATH="/home/hived/bin/hived"
export COMPRESS_BLOCK_LOG_PATH="/home/hived/bin/compress_block_log"
export DB_NAME=haf_block_log
export DB_ADMIN="haf_admin"
export SETUP_SCRIPTS_PATH="/home/haf_admin/haf/scripts"

echo -e "\e[0Ksection_start:$(date +%s):replay[collapsed=true]\r\e[0KExecuting replay..."
mkdir $DATADIR/blockchain -p
cp ${BLOCK_LOG_SOURCE_DIR_5M}/block_log $DATADIR/blockchain
$HIVED_PATH --data-dir "$DATADIR" $REPLAY --exit-before-sync --psql-url "postgresql:///$DB_NAME" 2>&1 | tee -i node_logs.log
echo -e "\e[0Ksection_end:$(date +%s):replay\r\e[0K"


psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "SELECT hive.app_create_context('metadata_live');"
psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "SELECT hive.app_state_provider_import('METADATA', 'metadata_live');"

echo "Replay of json/posting metadata..."
bash "${SCRIPTPATH}/json_metadata_comparison/process_klive.sh"

echo "Clearing tables..."
psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "TRUNCATE metadata_live.jsons;"
psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "TRUNCATE metadata_live.differing_accounts;"

echo "Installing dependencies..."
pip install psycopg2-binary

rm -f "${SCRIPTPATH}/json_metadata_comparison/accounts_dump.json"
# The line below is somewhat problematic. Gunzip by default deletes gz file after decompression,
# but the '-k' parameter, which prevents that from happening is not supported on some of its versions.
# 
# Thus, depending on the OS, the line below may need to be replaced with one of the following:
# gunzip -c "${SCRIPTDIR}/accounts_dump.json.gz" > "${SCRIPTDIR}/accounts_dump.json"
# gzcat "${SCRIPTDIR}/accounts_dump.json.gz" > "${SCRIPTDIR}/accounts_dump.json"
# zcat "${SCRIPTDIR}/accounts_dump.json.gz" > "${SCRIPTDIR}/accounts_dump.json"
gunzip -k "${SCRIPTPATH}/json_metadata_comparison/accounts_dump.json.gz"

echo "Starting data_insertion_script.py..."
python3 $SCRIPTPATH/json_metadata_comparison/data_insertion_script.py --script_dir="$SCRIPTPATH"/json_metadata_comparison --host="/var/run/postgresql" #--debug

echo "Looking for diffrences between hived node and metadata..."
psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "SELECT metadata_live.compare_accounts();"

DIFFERING_ACCOUNTS=$(psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -t -A -c "SELECT * FROM metadata_live.differing_accounts;")

if [ -z "$DIFFERING_ACCOUNTS" ]; then
    echo "metadata is correct!"
    exit 0
else
    echo "metadata is incorrect..."
    psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "SELECT * FROM metadata_live.differing_accounts;"
    exit 3
fi

test_end
