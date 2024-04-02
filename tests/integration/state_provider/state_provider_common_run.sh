#! /bin/bash


set -euo pipefail

NAME=$1

if [ ${NAME} = "keyauth" ]; then
  TYPE="KEYAUTH"
  TABLE_NAME="keys"
else
  TYPE="METADATA"
  TABLE_NAME="jsons"
fi

CURRENT_PROJECT_DIR="$CI_PROJECT_DIR/tests/integration/state_provider"
LOG_FILE=replay_with_${NAME}.log

source "$CURRENT_PROJECT_DIR/state_provider_common.sh"

test_start

echo -e "\e[0Ksection_start:$(date +%s):replay[collapsed=true]\r\e[0KExecuting replay..."
mkdir $DATADIR/blockchain -p
cp ${BLOCK_LOG_SOURCE_DIR_5M}/block_log $DATADIR/blockchain
cp ${CURRENT_PROJECT_DIR}/config.ini $DATADIR
$HIVED_PATH --data-dir "$DATADIR" $REPLAY --exit-before-sync --psql-url "postgresql:///$DB_NAME" 2>&1 | tee -i node_logs.log
echo -e "\e[0Ksection_end:$(date +%s):replay\r\e[0K"

psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "SELECT hive.app_create_context('${NAME}_live');"
psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "SELECT hive.app_state_provider_import('${TYPE}', '${NAME}_live');"

echo "Replay of ${NAME}..."
psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -f "${CURRENT_PROJECT_DIR}/${NAME}/${NAME}_live_schema.sql"
psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "CALL ${NAME}_live.main('${NAME}_live', 0, 5000000, 500000);" 

echo "Clearing tables..."
psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "TRUNCATE ${NAME}_live.${TABLE_NAME};"
psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "TRUNCATE ${NAME}_live.differing_accounts;"

echo "Installing dependencies..."
pip install psycopg2-binary

rm -f "${CURRENT_PROJECT_DIR}/account_data/accounts_dump.json"
# The line below is somewhat problematic. Gunzip by default deletes gz file after decompression,
# but the '-k' parameter, which prevents that from happening is not supported on some of its versions.
# 
# Thus, depending on the OS, the line below may need to be replaced with one of the following:
# gunzip -c "${SCRIPTDIR}/accounts_dump.json.gz" > "${SCRIPTDIR}/accounts_dump.json"
# gzcat "${SCRIPTDIR}/accounts_dump.json.gz" > "${SCRIPTDIR}/accounts_dump.json"
# zcat "${SCRIPTDIR}/accounts_dump.json.gz" > "${SCRIPTDIR}/accounts_dump.json"
gunzip -k "${CURRENT_PROJECT_DIR}/account_data/accounts_dump.json.gz"

echo "Starting data_insertion_script.py..."
python3 ${CURRENT_PROJECT_DIR}/data_insertion.py --script_dir="${CURRENT_PROJECT_DIR}/account_data" --host="/var/run/postgresql" --data_type="${NAME}" #--debug

echo "Looking for differences between hived node and ${NAME}..."
psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "SELECT ${NAME}_live.compare_accounts();"

DIFFERING_ACCOUNTS=$(psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -t -A -c "SELECT * FROM ${NAME}_live.differing_accounts;")

if [ -z "$DIFFERING_ACCOUNTS" ]; then
    echo "Result for ${NAME}: correct!"
    exit 0
else
    echo "Result for ${NAME}: differences found. Incorrect."
    psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "SELECT * FROM ${NAME}_live.differing_accounts;"
    exit 3
fi

test_end
