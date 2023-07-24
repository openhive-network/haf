#! /bin/bash

set -xeuo pipefail

REPO_DIR=/home/haf_admin/haf
# check if variable CI_PROJECT_DIR is set
if test -n "${CI_PROJECT_DIR+x}"
then
    REPO_DIR="$CI_PROJECT_DIR"
fi


test_start() {

  pushd "$REPO_DIR"
  echo "Will use tests from commit $(git rev-parse HEAD)"
  exec > >(tee -i "${LOG_FILE}") 2>&1
}

test_end() {

  echo done
}
