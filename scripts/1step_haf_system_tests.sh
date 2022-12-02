#! /bin/bash

set -euo pipefail

LOG_FILE=1step_haf_system_tests.log

# Because this script should work as standalone script being just downloaded from gitlab repo, and next use internal
# scripts from a cloned repo, logging code is duplicated.

exec > >(tee "${LOG_FILE}") 2>&1

log_exec_params() {
  echo
  echo -n "$0 parameters: "
  for arg in "$@"; do echo -n "$arg "; done
  echo
}

log_exec_params "$@" 

pwd

echo "/home/haf_admin/workspace directory contents:"

ls -la /home/haf_admin/workspace

cd /home/haf_admin/workspace

mkdir -pv haf-test/haf

cd haf-test

git clone --branch master https://github.com/wolfcw/libfaketime.git
cd libfaketime 
make

cd /home/haf_admin/workspace/haf-test/haf/

git clone --recurse --branch develop git@gitlab.syncad.com:hive/haf.git .

mkdir -pv /home/haf_admin/workspace/haf-test/haf/build

cd /home/haf_admin/workspace/haf-test/haf/build

cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_HIVE_TESTNET=ON -GNinja ../
ninja -j6

sudo /home/haf_admin/workspace/haf-test/haf/scripts/setup_postgres.sh --haf-admin-account=haf_admin --haf-binaries-dir="/home/haf_admin/workspace/haf-test/haf/build"

export PYTHONPATH=/home/haf_admin/workspace/haf-test/haf/tests/integration/local_tools
export LIBFAKETIME_PATH=/home/haf_admin/workspace/libfaketime/src/libfaketime.so.1

cd /home/haf_admin/workspace/haf-test/haf/tests/integration/system/haf

tox .

