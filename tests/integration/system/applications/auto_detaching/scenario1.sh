#! /bin/bash
set -xeuo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

SCRIPTSDIR="$SCRIPTPATH/../../../../../scripts"

export LOG_FILE=scenario1.log
# shellcheck source=../common.sh
source "$SCRIPTSDIR/common.sh"

POSTGRES_HOST=${1:-"172.17.0.3"}

POSTRGRES_APP_URL="postgresql://test_app_owner@${POSTGRES_HOST}/haf_block_log"
POSTRGRES_ADMIN_URL="postgresql://haf_admin@${POSTGRES_HOST}/haf_block_log"

POSTGRES_ARGS="-aw -v ON_ERROR_STOP=ON"

psql "${POSTRGRES_ADMIN_URL}" ${POSTGRES_ARGS} -f "${SCRIPTPATH}/test_app.sql"
psql "${POSTRGRES_ADMIN_URL}" ${POSTGRES_ARGS} -f "${SCRIPTPATH}/test_utils.sql"
psql "${POSTRGRES_APP_URL}" ${POSTGRES_ARGS} -f "${SCRIPTPATH}/scenario1.sql"

# Now execute test

TIMESHIFT="'3 hrs'::interval"

psql "${POSTRGRES_APP_URL}" ${POSTGRES_ARGS} -c "CALL test.scenario1_prepare(${TIMESHIFT});"

psql "${POSTRGRES_ADMIN_URL}" ${POSTGRES_ARGS} -c 'SET ROLE haf_maintainer;' -c "CALL hive.proc_perform_dead_app_contexts_auto_detach(${TIMESHIFT} - '1 min'::interval);"

psql "${POSTRGRES_APP_URL}" ${POSTGRES_ARGS} -c "SET ROLE test_app_owner; CALL test.scenario1_verify(${TIMESHIFT});"

