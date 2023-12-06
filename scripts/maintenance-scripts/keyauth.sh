#! /bin/bash


set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."
LOG_FILE=replay_with_keyauths.log

source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"

#test_start

# container must have /blockchain directory mounted containing block_log with at 5000000 first blocks

export DB_NAME=haf_block_log
export DB_ADMIN="haf_admin"

print_help () {
cat <<EOF
  Usage: $0 [OPTION[=VALUE]]...

  Processes blocks using Haf Block Explorer
  OPTIONS:
    --host=HOST             PostgreSQL host (defaults to localhost)
    --port=PORT             PostgreSQL operating port (defaults to 5432)
    --user=USER             PostgreSQL username (defaults to hafbe_owner)
    --limit=LIMIT           Max number of blocks to process (0 for infinite, defaults to 0)
    --log-file              Log file location (defaults to hafbe_sync.log, set to 'STDOUT' to log to STDOUT only)
EOF
}

POSTGRES_HOST=${POSTGRES_HOST:-"localhost"}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_USER=${POSTGRES_USER:-"haf_admin"}
PROCESS_BLOCK_LIMIT=${PROCESS_BLOCK_LIMIT:-0}
LOG_FILE=${LOG_FILE:-"hafbe_sync.log"}

while [ $# -gt 0 ]; do
  case "$1" in
    --host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --port=*)
        POSTGRES_PORT="${1#*=}"
        ;;
    --user=*)
        POSTGRES_USER="${1#*=}"
        ;;
    --limit=*)
        PROCESS_BLOCK_LIMIT="${1#*=}"
        ;;
    --log-file=*)
        LOG_FILE="${1#*=}"
        ;;
    --help|-h|-?)
        print_help
        exit 0
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option"
        echo
        print_help
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument"
        echo
        print_help
        exit 2
        ;;
    esac
    shift
done

POSTGRES_ACCESS="postgresql://$POSTGRES_USER@$POSTGRES_HOST:$POSTGRES_PORT/haf_block_log"




echo "Replay of keyauths..."
bash "${SCRIPTPATH}/keyauths_comparison/process_klive.sh"

echo "Clearing tables..."
psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "TRUNCATE keyauth_live.keys;"
psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c"TRUNCATE keyauth_live.differing_accounts;"

echo "Installing dependecies..."
pip install psycopg2-binary

rm -f "${SCRIPTPATH}/keyauths_comparison/accounts_dump.json"
# The line below is somewhat problematic. Gunzip by default deletes gz file after decompression,
# but the '-k' parameter, which prevents that from happening is not supported on some of its versions.
# 
# Thus, depending on the OS, the line below may need to be replaced with one of the following:
# gunzip -c "${SCRIPTDIR}/accounts_dump.json.gz" > "${SCRIPTDIR}/accounts_dump.json"
# gzcat "${SCRIPTDIR}/accounts_dump.json.gz" > "${SCRIPTDIR}/accounts_dump.json"
# zcat "${SCRIPTDIR}/accounts_dump.json.gz" > "${SCRIPTDIR}/accounts_dump.json"
gunzip -k "${SCRIPTPATH}/keyauths_comparison/accounts_dump.json.gz"

echo "Starting data_insertion_script.py..."
python3 $SCRIPTPATH/keyauths_comparison/data_insertion_script.py "$SCRIPTPATH"/keyauths_comparison --host="172.17.0.2" #--debug

echo "Looking for diffrences between hived node and keyauths..."
psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "SELECT keyauth_live.compare_accounts();"

DIFFERING_ACCOUNTS=$(psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -t -A -c "SELECT * FROM keyauth_live.differing_accounts;")

if [ -z "$DIFFERING_ACCOUNTS" ]; then
    echo "keyauths are correct!"
    exit 0
else
    echo "keyauths are incorrect..."
    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "SELECT * FROM keyauth_live.differing_accounts;"
    exit 3
fi

#test_end