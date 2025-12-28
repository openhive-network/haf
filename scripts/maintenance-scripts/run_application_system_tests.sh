#! /bin/bash
set -xeuo pipefail

# Install Python 3.14 from deadsnakes PPA (HAF image has Python 3.12)
sudo apt-get update
sudo apt-get install -y software-properties-common
# Use python3.12 explicitly since apt_pkg is compiled for it
sudo /usr/bin/python3.12 /usr/bin/add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get update
sudo apt-get install -y git python3.14 python3.14-venv python3.14-dev

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

export LOG_FILE=applications_system_tests.log
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
python3.14 -m venv venv/
# shellcheck disable=SC1091
. venv/bin/activate
python3.14 -m pip install pipx
python3.14 -m pipx ensurepath
pipx install poetry
(cd "${REPO_DIR}/tests/integration/haf-local-tools" && poetry install)
echo -e "\e[0Ksection_end:$(date +%s):python_venv\r\e[0K"


cd "${REPO_DIR}/tests/integration/system/applications"
pytest --junitxml report.xml -n "${PYTEST_NUMBER_OF_PROCESSES}" -m "not mirrornet" "${ARGS[@]}"

test_end
