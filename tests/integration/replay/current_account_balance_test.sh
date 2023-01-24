#! /bin/bash


# set -xeuo pipefail
set -x

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
BASE_DIRECTORY=/$(echo "$SCRIPTPATH" | cut -d "/" -f2)
SOURCE_DATA_DIR=$CI_PROJECT_DIR/data_generated_during_hive_replay
mkdir -p "$SOURCE_DATA_DIR"
env | sort
pwd

POSTGRESLOG=$(find / -name postgresql*.log)
echo $POSTGRESLOG
P=$(echo $POSTGRESLOG | cut -d'/' -f-2)
echo P=$P
ls -lah $P || true

P=$(echo $POSTGRESLOG | cut -d'/' -f-3)
echo P=$P
ls -lah $P || true

P=$(echo $POSTGRESLOG | cut -d'/' -f-4)
echo P=$P
ls -lah $P || true

P=$(echo $POSTGRESLOG | cut -d'/' -f-5)
echo P=$P
ls -lah $P || true


ls -lah $POSTGRESLOG || true
echo "mtlk Listing 10 000 last lines of postgres log"
sudo tail -n 10000 $POSTGRESLOG
echo "mtlk end listing postgres log"



$SETUP_SCRIPTS_PATH/runallnow.sh app_start || true

echo "mtlk Listing2 10 000 last lines of postgres log"
sudo tail -n 10000 $POSTGRESLOG
echo "mtlk end listing2 postgres log"


$SETUP_SCRIPTS_PATH/runallnow.sh app_cont || true

echo "mtlk Listing3 10 000 last lines of postgres log"
sudo tail -n 10000 $POSTGRESLOG
echo "mtlk end listing3 postgres log"

