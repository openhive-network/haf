#! /bin/bash
set -xeuo pipefail

sudo apt-get update
sudo apt-get install -y git cmake libpq-dev python3 python3-dev python3-venv python3-pip ninja-build build-essential liburing-dev libboost-all-dev libssl-dev bzip2 libbz2-dev libsnappy-dev \
  python3-jinja2 libreadline-dev postgresql-server-dev-17 zopfli libpqxx-dev xxd

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

export LOG_FILE=hfm_functional_tests.log
# shellcheck source=./ci_common.sh
source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"

HAF_SOURCE_DIR="/home/haf_admin/source"

rm -rf "${HAF_SOURCE_DIR}"
mkdir -p "${HAF_SOURCE_DIR}"

# Since the source is not a part of the minimal image, we need to check it out
git clone https://gitlab.syncad.com/hive/haf.git "${HAF_SOURCE_DIR}"
pushd "${HAF_SOURCE_DIR}"
echo "Checking out commit ${HAF_COMMIT} into ${HAF_SOURCE_DIR}"
git checkout "${HAF_COMMIT}"
git submodule update --init --recursive

# The we need to build the source we just checked out
"${SCRIPTSDIR}/build.sh" --haf-source-dir="${HAF_SOURCE_DIR}" --haf-binaries-dir="/home/haf_admin/build" \
  --cmake-arg="-DBUILD_HIVE_TESTNET=${BUILD_HIVE_TESTNET}" \
  --cmake-arg="-DENABLE_SMT_SUPPORT=${ENABLE_SMT_SUPPORT}" \
  --cmake-arg="-DHIVE_CONVERTER_BUILD=${HIVE_CONVERTER_BUILD}" \
  --cmake-arg="-DHIVE_LINT=${HIVE_LINT}"

test_start

export CTEST_NUMBER_OF_JOBS="${CTEST_NUMBER_OF_JOBS:-4}"

pushd "/home/haf_admin/build"

# du --human-readable "$(pwd)"

ctest --parallel "${CTEST_NUMBER_OF_JOBS}" --output-on-failure -R test.functional.hive_fork_manager*
ctest --parallel "${CTEST_NUMBER_OF_JOBS}" --output-on-failure -R test_update_script
ctest --parallel "${CTEST_NUMBER_OF_JOBS}" --output-on-failure -R test.functional.update.hive_fork_manager*
ctest --output-on-failure -R test.functional.query_supervisor.*
ctest --output-on-failure -R test.unit.*

popd

test_end
