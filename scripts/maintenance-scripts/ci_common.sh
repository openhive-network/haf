#! /bin/bash

set -xeuo pipefail

SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
export REPO_DIR="${SCRIPTDIR}/../../"
export SETUP_SCRIPTS_PATH="${REPO_DIR}/scripts"

export HIVED_PATH=${HIVED_PATH:-"/home/hived/bin/hived"}
export COMPRESS_BLOCK_LOG_PATH=${COMPRESS_BLOCK_LOG_PATH:-"/home/hived/bin/compress_block_log"}
export BLOCK_LOG_UTIL_PATH=${BLOCK_LOG_UTIL_PATH:-"/home/hived/bin/block_log_util"}
export GET_DEV_KEY_PATH=${GET_DEV_KEY_PATH:-"/home/hived/bin/get_dev_key"}
export CLI_WALLET_PATH=${CLI_WALLET_PATH:-"/home/hived/bin/cli_wallet"}
export OP_BODY_FILTER_PATH=${OP_BODY_FILTER_PATH:-"/builds/hive/haf/haf-testnet-binaries/op_body_filter"}
# export OP_BODY_FILTER_PATH=${OP_BODY_FILTER_PATH:-"${HAF_SOURCE_DIR:?"HAF source directory must be set"}/../build/bin/op_body_filter"}

export DB_NAME=haf_block_log
export DB_ADMIN="haf_admin"

test_start() {
  pushd "${REPO_DIR}"
  git config --global --add safe.directory "$(realpath "${REPO_DIR}")"
  echo "Will use tests from commit $(git rev-parse HEAD)"
  exec > >(tee -i "${LOG_FILE}") 2>&1
}

test_end() {
  echo "Done!"
}
