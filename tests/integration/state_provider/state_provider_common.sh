#! /bin/bash

set -xeuo pipefail

export REPO_DIR="$CI_PROJECT_DIR"

# container must have /blockchain directory mounted containing block_log with at 5000000 first blocks
export BLOCK_LOG_SOURCE_DIR_5M="/blockchain/block_log_5m"

export DATADIR="$CI_PROJECT_DIR/datadir"

# Check available disk space before starting replay tests
# These tests require ~30GB for PostgreSQL database + temp files
echo "=== Disk Space Check ==="
REQUIRED_FREE_GB=30
CURRENT_FREE_KB=$(df -k "$CI_PROJECT_DIR" 2>/dev/null | tail -1 | awk '{print $4}')
CURRENT_FREE_GB=$((CURRENT_FREE_KB / 1024 / 1024))
echo "Free space: ${CURRENT_FREE_GB}GB (need at least ${REQUIRED_FREE_GB}GB)"
if [[ $CURRENT_FREE_GB -lt $REQUIRED_FREE_GB ]]; then
  echo "WARNING: Insufficient disk space, attempting cleanup..."
  # Try to clean up temp files and old builds
  rm -rf /tmp/* 2>/dev/null || true
  rm -rf "$CI_PROJECT_DIR"/../*/datadir 2>/dev/null || true
  CURRENT_FREE_KB=$(df -k "$CI_PROJECT_DIR" 2>/dev/null | tail -1 | awk '{print $4}')
  CURRENT_FREE_GB=$((CURRENT_FREE_KB / 1024 / 1024))
  echo "Free space after cleanup: ${CURRENT_FREE_GB}GB"
  if [[ $CURRENT_FREE_GB -lt $REQUIRED_FREE_GB ]]; then
    echo "ERROR: Still insufficient disk space after cleanup. Test may fail."
  fi
fi
echo "=== End Disk Space Check ==="
export REPLAY=("--replay-blockchain" "--stop-at-block=5000000")
export HIVED_PATH=${HIVED_PATH:-"/home/hived/bin/hived"}
export COMPRESS_BLOCK_LOG_PATH=${COMPRESS_BLOCK_LOG_PATH:-"/home/hived/bin/compress_block_log"}
export DB_NAME=haf_block_log
export DB_ADMIN="haf_admin"
export SETUP_SCRIPTS_PATH="/home/haf_admin/haf/scripts"

test_start() {
  pushd "$REPO_DIR"
  echo "Will use tests from commit $(git rev-parse HEAD)"
  exec > >(tee -i "${LOG_FILE}") 2>&1
}

test_end() {
  echo "Done!"
}
