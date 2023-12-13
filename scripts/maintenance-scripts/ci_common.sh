#! /bin/bash

set -xeuo pipefail

SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
REPO_DIR="${SCRIPTDIR}/../../"

test_start() {

  pushd "$REPO_DIR"
  echo "Will use tests from commit $(git rev-parse HEAD)"
  exec > >(tee -i "${LOG_FILE}") 2>&1
}

test_end() {

  echo done
}
