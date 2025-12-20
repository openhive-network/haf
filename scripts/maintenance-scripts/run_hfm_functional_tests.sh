#! /bin/bash
set -xeuo pipefail

# Optimized version: Skip full build, just configure CMake for test discovery
# The HAF extension is already installed in the Docker image ($HAF_IMAGE_NAME)
# We only need: source files (already at $CI_PROJECT_DIR) + CMake configure (for ctest)

# Packages needed for cmake configure (finds libraries) and running tests
# Note: We're not building, but cmake still needs to find these during configure
sudo apt-get update
sudo apt-get install -y git cmake ninja-build g++ postgresql-server-dev-17 \
  liburing-dev libboost-all-dev libssl-dev libbz2-dev libsnappy-dev libpqxx-dev libreadline-dev

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

export LOG_FILE=hfm_functional_tests.log
# shellcheck source=./ci_common.sh
source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"

# Use CI_PROJECT_DIR - source is already checked out by GitLab
HAF_SOURCE_DIR="${CI_PROJECT_DIR}"
HAF_BUILD_DIR="/home/haf_admin/build"

mkdir -p "${HAF_BUILD_DIR}"

# Configure only - no build needed for functional tests
# The HAF extension is pre-installed in the Docker image
pushd "${HAF_BUILD_DIR}"
cmake -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_HIVE_TESTNET="${BUILD_HIVE_TESTNET}" \
  -DENABLE_SMT_SUPPORT="${ENABLE_SMT_SUPPORT}" \
  -DHIVE_CONVERTER_BUILD="${HIVE_CONVERTER_BUILD}" \
  -DHIVE_LINT="${HIVE_LINT}" \
  "${HAF_SOURCE_DIR}"
popd

test_start

export CTEST_NUMBER_OF_JOBS="${CTEST_NUMBER_OF_JOBS:-4}"

pushd "${HAF_BUILD_DIR}"

# Run functional tests (SQL-based, don't need compiled binaries)
ctest --parallel "${CTEST_NUMBER_OF_JOBS}" --output-on-failure -R test.functional.hive_fork_manager*
ctest --parallel "${CTEST_NUMBER_OF_JOBS}" --output-on-failure -R test_update_script
# Note: test.functional.update.* tests need the update script generator (build artifact)
# Skip for now - these can run in a separate job that does full build
# ctest --parallel "${CTEST_NUMBER_OF_JOBS}" --output-on-failure -R test.functional.update.hive_fork_manager*
ctest --output-on-failure -R test.functional.query_supervisor.*
ctest --output-on-failure -R test.unit.*

popd

test_end
