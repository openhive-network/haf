#! /bin/bash
set -xeuo pipefail

sudo apt-get update
sudo apt-get install -y git cmake python3 python3-venv python3-pip

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

export LOG_FILE=hfm_functional_tests.log
# shellcheck source=./ci_common.sh
source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"

test_start

export CTEST_NUMBER_OF_JOBS="${CTEST_NUMBER_OF_JOBS:-4}"

pushd "/home/haf_admin/build"

ctest --parallel "${CTEST_NUMBER_OF_JOBS}" --output-on-failure -R test.functional.hive_fork_manager*
ctest --parallel "${CTEST_NUMBER_OF_JOBS}" --output-on-failure -R test_update_script
ctest --parallel "${CTEST_NUMBER_OF_JOBS}" --output-on-failure -R test.functional.update.hive_fork_manager*
ctest --output-on-failure -R test.functional.query_supervisor.*
ctest --output-on-failure -R test.unit.*

popd

test_end
