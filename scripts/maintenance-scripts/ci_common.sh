#! /bin/bash

set -xeuo pipefail

SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
export REPO_DIR="${SCRIPTDIR}/../../"
export SETUP_SCRIPTS_PATH="${REPO_DIR}/scripts"

export HIVED_PATH="/home/hived/bin/hived"
export COMPRESS_BLOCK_LOG_PATH="/home/hived/bin/compress_block_log"
export GET_DEV_KEY_PATH="/home/hived/bin/get_dev_key"
export CLI_WALLET_PATH="/home/hived/bin/cli_wallet"

export DB_NAME=haf_block_log
export DB_ADMIN="haf_admin"

test_start() {

  pushd "$REPO_DIR"
  echo "Will use tests from commit $(git rev-parse HEAD)"
  exec > >(tee -i "${LOG_FILE}") 2>&1
}

test_end() {

  echo done
}
