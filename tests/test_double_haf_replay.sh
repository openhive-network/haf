#! /bin/bash

set -xeuo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
BASE_DIRECTORY=/$(echo "$SCRIPTPATH" | cut -d "/" -f2)
SOURCE_DATA_DIR=$CI_PROJECT_DIR/data_generated_during_hive_replay
mkdir -p "$SOURCE_DATA_DIR"

echo "CREATE REPLAY ENVIRONMENT"
"$SETUP_SCRIPTS_PATH/ci-helpers/prepare_data_and_shm_dir.sh" --data-base-dir="$SOURCE_DATA_DIR" --block-log-source-dir="$BLOCK_LOG_SOURCE_DIR_5M" --config-ini-source="$CONFIG_INI_SOURCE"

echo "START FIRST REPLAY: "
"$SETUP_SCRIPTS_PATH"/run_hived_img.sh "$HAF_IMAGE_NAME" --data-dir="$SOURCE_DATA_DIR"/datadir --name=haf-instance-5M --replay --stop-replay-at-block=100000 --exit-before-sync --psql-index-threshold=60000 --detach
echo "Logs from first container hived_instance:"
docker logs -f haf-instance-5M &
test "$(docker wait haf-instance-5M)" = 0

"$SETUP_SCRIPTS_PATH"/run_hived_img.sh "$HAF_IMAGE_NAME" --data-dir="$SOURCE_DATA_DIR"/datadir --name=haf-instance-5M --replay --stop-replay-at-block=1 --detach
docker logs -f haf-instance-5M &
docker container exec haf-instance-5M /home/haf_admin/haf/scripts/psql_run.sh


echo "CHECK THE NUMBER OF REPLAYED BLOCKS"
cat "$SOURCE_DATA_DIR"/datadir/psql.log
grep "[ ]100000$" "$SOURCE_DATA_DIR"/datadir/psql.log
docker stop haf-instance-5M


echo "START SECOND REPLAY: "
"$SETUP_SCRIPTS_PATH"/run_hived_img.sh "$HAF_IMAGE_NAME" --data-dir="$SOURCE_DATA_DIR"/datadir --name=haf-instance-5M --replay --stop-replay-at-block=150000 --exit-before-sync --psql-index-threshold=60000 --detach
echo "Logs from second container hived_instance:"
docker logs -f haf-instance-5M &
test "$(docker wait haf-instance-5M)" = 0


"$SETUP_SCRIPTS_PATH"/run_hived_img.sh "$HAF_IMAGE_NAME" --data-dir="$SOURCE_DATA_DIR"/datadir --name=haf-instance-5M --replay --stop-replay-at-block=1 --detach
docker logs -f haf-instance-5M &
docker container exec haf-instance-5M /home/haf_admin/haf/scripts/psql_run.sh

echo "CHECK THE NUMBER OF REPLAYED BLOCKS"
cat "$SOURCE_DATA_DIR"/datadir/psql.log
grep "[ ]150000$" "$SOURCE_DATA_DIR"/datadir/psql.log
docker stop haf-instance-5M

echo "Test passed!"

