#! /bin/bash

set -x
set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
BASE_DIRECTORY=/$(echo "$SCRIPTPATH" | cut -d "/" -f2)
SOURCE_DATA_DIR=$CI_PROJECT_DIR/data_generated_during_hive_replay
mkdir -p "$SOURCE_DATA_DIR"

POSTGRESLOG=$(find /var/log -name postgresql*.log) || true

echo "POSTGRESLOG ### Starting ### after init"
sudo tail -n 10000 $POSTGRESLOG
echo "POSTGRESLOG ### Finished ### after init"


$SETUP_SCRIPTS_PATH/../tests/integration/bash/consensus_state_provider/run_app.sh app_start || true

echo "POSTGRESLOG ### Starting ### after app_start"
sudo tail -n 10000 $POSTGRESLOG
echo "POSTGRESLOG ### Finished ### after app_start"

set -E

on_error()
{
    echo "POSTGRESLOG ### Starting ### on error:"
    sudo tail -n 10000 $POSTGRESLOG
    echo "POSTGRESLOG ### Starting ### on error:"
}

trap on_error ERR


$SETUP_SCRIPTS_PATH/../tests/integration/bash/consensus_state_provider/run_app.sh app_cont

set +E

echo "POSTGRESLOG ### Starting ### app_cont"
sudo tail -n 10000 $POSTGRESLOG
echo "POSTGRESLOG ### Finished ### after app_cont"


