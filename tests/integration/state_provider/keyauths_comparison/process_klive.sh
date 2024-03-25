#!/bin/bash

set -e
set -o pipefail

SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

export DB_NAME=haf_block_log
export DB_ADMIN="haf_admin"

process_blocks() {
    psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -f "${SCRIPTDIR}/keyauth_live_schema.sql"
    psql -w -d $DB_NAME -v ON_ERROR_STOP=on -U $DB_ADMIN -c "CALL keyauth_live.main('keyauth_live', 0, 5000000, 500000);" 
}



process_blocks $PROCESS_BLOCK_LIMIT