#! /bin/bash
set -xeuo pipefail

sudo apt-get update
sudo apt-get install -y git python3 python3-venv python3-pip
python3 -m pip install --user pipx
python3 -m pipx ensurepath
pipx install poetry

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

export LOG_FILE=haf_system_tests.log
# shellcheck source=./ci_common.sh
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
export DB_URL="postgresql://haf_admin@127.0.0.1:5432/$DB_NAME"

echo -e "\e[0Ksection_start:$(date +%s):python_venv[collapsed=true]\r\e[0KCreating Python virtual environment..."
python3 -m venv --system-site-packages venv/
# shellcheck disable=SC1091
. venv/bin/activate
(cd "${REPO_DIR}/tests/integration/haf-local-tools" && poetry install)
echo -e "\e[0Ksection_end:$(date +%s):python_venv\r\e[0K"

cd "${REPO_DIR}/tests/integration/system/haf"
pytest --junitxml report.xml -n "${PYTEST_NUMBER_OF_PROCESSES}" -m "not mirrornet" "${ARGS[@]}"

test_end
