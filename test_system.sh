#!/bin/sh

# build image
./scripts/ci-helpers/build_instance.sh --network-type=mainnet local ~/src/haf registry.gitlab.syncad.com/hive/haf

# start container
docker run --rm -v .:/tmp/src -v /storage_nvme/blocks:/blockchain  registry.gitlab.syncad.com/hive/haf:local --execute-maintenance-script=/tmp/src/scripts/maintenance-scripts/run_live_pruned_replay_with_app.sh
