#! /bin/bash

set -x
set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
BASE_DIRECTORY=/$(echo "$SCRIPTPATH" | cut -d "/" -f2)
SOURCE_DATA_DIR=$CI_PROJECT_DIR/data_generated_during_hive_replay
mkdir -p "$SOURCE_DATA_DIR"
env | sort
pwd

POSTGRESLOG=$(find / -name postgresql*.log) || true
echo $POSTGRESLOG


sudo ls -lah $PATTERNS_PATH || true
sudo ls -lah $PATTERNS_PATH/context || true


ls -lah $POSTGRESLOG || true
echo "mtlk Listing 10 000 last lines of postgres log"
sudo tail -n 10000 $POSTGRESLOG
echo "mtlk end listing postgres log"


$SETUP_SCRIPTS_PATH/runallnow.sh app_start || true

echo "mtlk Listing2 10 000 last lines of postgres log"
sudo tail -n 10000 $POSTGRESLOG
echo "mtlk end listing2 postgres log"

set -E


on_error()
{
    echo "mtlk Listing on_error 10 000 last lines of postgres log"
    sudo tail -n 10000 $POSTGRESLOG
    echo "mtlk end Listing on_error postgres log"
}

trap on_error ERR


$SETUP_SCRIPTS_PATH/runallnow.sh app_cont

set +E

echo "mtlk Listing3 10 000 last lines of postgres log"
sudo tail -n 10000 $POSTGRESLOG
echo "mtlk end listing3 postgres log"

