#! /bin/bash
set -xeuo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

LOG_FILE=applications_system_tests.log
source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"

ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        *)
        echo "Attempting to collect option: ${1}"
        ARGS+=("$1")
        ;;
    esac
    shift
done

test_start

export PYTEST_NUMBER_OF_PROCESSES="${PYTEST_NUMBER_OF_PROCESSES:-8}"
export HIVED_PATH="/home/hived/bin/hived"
export COMPRESS_BLOCK_LOG_PATH="/home/hived/bin/compress_block_log"
export GET_DEV_KEY_PATH="/home/hived/bin/get_dev_key"
export CLI_WALLET_PATH="/home/hived/bin/cli_wallet"
export DB_NAME=haf_block_log
export DB_URL="postgresql://haf_admin@127.0.0.1:5432/$DB_NAME"

echo -e "\e[0Ksection_start:$(date +%s):python_venv[collapsed=true]\r\e[0KCreating Python virtual environment..."
python3 -m venv --system-site-packages venv/
. venv/bin/activate
(cd "${REPO_DIR}/tests/integration/haf-local-tools" && poetry install)
echo -e "\e[0Ksection_end:$(date +%s):python_venv\r\e[0K"


cd "${REPO_DIR}/tests/integration/system/applications"
pytest --junitxml report.xml -n "${PYTEST_NUMBER_OF_PROCESSES}" -m "not mirrornet" ${ARGS[@]}

test_end
