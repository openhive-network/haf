#! /bin/bash

set -xeuo pipefail

export REPO_DIR="$CI_PROJECT_DIR"

# container must have /blockchain directory mounted containing block_log with at 5000000 first blocks
export BLOCK_LOG_SOURCE_DIR_5M="/blockchain/block_log_5m"

export DATADIR="$CI_PROJECT_DIR/datadir"
export REPLAY=("--replay-blockchain" "--stop-at-block=5000000")
export HIVED_PATH=${HIVED_PATH:-"/home/hived/bin/hived"}
export COMPRESS_BLOCK_LOG_PATH=${COMPRESS_BLOCK_LOG_PATH:-"/home/hived/bin/compress_block_log"}
export DB_NAME=haf_block_log
export DB_ADMIN="haf_admin"
export SETUP_SCRIPTS_PATH="/home/hived/source/scripts"

collect_pg_logs() {
  # Postgres server logs are the only place a backend crash (segfault in an
  # extension) is recorded; the datadir itself is cleaned up with the workspace,
  # so copy them somewhere the artifacts globs can reach.
  mkdir -p "$CI_PROJECT_DIR/pg_logs"
  sudo cp -r "$DATADIR/haf_db_store/pgdata/log" "$CI_PROJECT_DIR/pg_logs/" 2>/dev/null || true
  sudo cp "$CI_PROJECT_DIR"/setup_postgres.log "$CI_PROJECT_DIR/pg_logs/" 2>/dev/null || true
  sudo chmod -R a+r "$CI_PROJECT_DIR/pg_logs" || true
}

test_start() {
  pushd "$REPO_DIR"
  echo "Will use tests from commit $(git rev-parse HEAD)"
  exec > >(tee -i "${LOG_FILE}") 2>&1
  trap collect_pg_logs EXIT
}

test_end() {
  echo "Done!"
}
