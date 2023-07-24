#! /bin/bash
set -xeuo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

LOG_FILE=hfm_functional_tests.log
source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"


test_start

export CTEST_NUMBER_OF_JOBS="${CTEST_NUMBER_OF_JOBS:-4}"

cd "/home/haf_admin/build" && ctest -j${CTEST_NUMBER_OF_JOBS} --output-on-failure -R test.functional.hive_fork_manager*
cd "/home/haf_admin/build" && ctest --output-on-failure -R test.functional.query_supervisor.*
cd "/home/haf_admin/build" && ctest --output-on-failure -R test.unit.*

test_end
