#!/bin/bash

set -e
set -o pipefail


print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Allows to start block processing by Haf Block Explorer application."
    echo "OPTIONS:"
    echo "  --host=VALUE             Allows to specify a PostgreSQL host location (defaults to localhost)"
    echo "  --port=NUMBER            Allows to specify a PostgreSQL operating port (defaults to 5432)"
    echo "  --user=VALUE             Allows to specify a PostgreSQL user (defaults to hafbe_owner)"
    echo "  --limit=VALUE            Allows to specify a limit for processing blocks,"
}

POSTGRES_HOST="localhost"
POSTGRES_PORT=5432
POSTGRES_USER="haf_admin"
PROCESS_BLOCK_LIMIT=0

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
    --help)
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

process_blocks() {
    n_blocks="${1:-null}"
    log_file="katest.log"
    psql $POSTGRES_ACCESS -v "ON_ERROR_STOP=on" -c "\timing" -c "SELECT katest.main_test('katest',1, 12200000,10000);" 2>&1 | ts '%Y-%m-%d %H:%M:%.S' | tee -i $log_file
}

process_blocks $PROCESS_BLOCK_LIMIT
