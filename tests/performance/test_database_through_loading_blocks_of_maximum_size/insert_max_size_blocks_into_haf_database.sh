#!/bin/bash

IMAGE_NAME=$1
SIGN_TYPE=$2
GENERATOR_PATH="/home/haf_admin/source/tests/performance/test_database_through_loading_blocks_of_maximum_size/full_block_generator.py"
BLOCK_LOG_DIRECTORY="/home/haf_admin/source/tests/performance/test_database_through_loading_blocks_of_maximum_size/block_log_$SIGN_TYPE"

docker create --name temp $IMAGE_NAME
docker cp temp:"$BLOCK_LOG_DIRECTORY/timestamp" "/tmp/timestamp"
timestamp=$(cat "/tmp/timestamp")
LAST_BLOCK_TIME=$(date -d "$timestamp" +"%Y-%m-%d %H:%M:%S")
docker rm temp

echo "Run container with faketime at time: $LAST_BLOCK_TIME"
docker run \
--rm \
-it \
-e HIVE_BUILD_ROOT_PATH="/home/haf_admin/build/hive" \
-e PYTEST_NUMBER_OF_PROCESSES="0" \
-e PG_ACCESS="host all all 127.0.0.1/32 trust" \
-e LD_PRELOAD="/home/hived_admin/hive_base_config/faketime/src/libfaketime.so.1" \
-e OVERRIDE_LD_PRELOAD="/home/hived_admin/hive_base_config/faketime/src/libfaketime.so.1" \
-e FAKETIME="$(($(date -d "$LAST_BLOCK_TIME UTC" +%s) - $(date -u +%s)))s" \
-e FAKETIME_DONT_FAKE_MONOTONIC=1 \
-e FAKETIME_DONT_RESET=1 \
-e TZ="UTC" \
--entrypoint /bin/bash \
$IMAGE_NAME \
-c " \
. /home/haf_admin/source/haf_venv/bin/activate; \
python3 $GENERATOR_PATH & \
. /home/haf_admin/docker_entrypoint.sh --p2p-seed-node=0.0.0.0:2000 --chain-id=24  --alternate-chain-spec=$BLOCK_LOG_DIRECTORY/alternate-chain-spec.json; \
"
