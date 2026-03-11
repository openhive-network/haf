#! /bin/bash
set -xeuo pipefail

# Install Python 3.14 if not already available (HAF image should have it)
if ! command -v python3.14 &>/dev/null; then
  # Add PPA manually to avoid add-apt-repository which fails in DinD due to IPv6/Launchpad API issues
  sudo apt-get update
  sudo apt-get install -y gnupg curl
  echo "deb https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu noble main" | sudo tee /etc/apt/sources.list.d/deadsnakes-ppa.list
  curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF23C5A6CF475977595C89F51BA6932366A755776" | sudo gpg --batch --dearmor -o /etc/apt/trusted.gpg.d/deadsnakes-ppa.gpg
  sudo apt-get update
  sudo apt-get install -y git python3.14 python3.14-venv python3.14-dev
fi

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

export LOG_FILE=haf_forking_tests.log
# shellcheck source=./ci_common.sh
source "$SCRIPTSDIR/maintenance-scripts/ci_common.sh"

test_start

export PYTEST_NUMBER_OF_PROCESSES="${PYTEST_NUMBER_OF_PROCESSES:-4}"
export DB_URL="postgresql://haf_admin@127.0.0.1:5432/$DB_NAME"

echo -e "\e[0Ksection_start:$(date +%s):python_venv[collapsed=true]\r\e[0KCreating Python virtual environment..."
python3.14 -m venv venv/
# shellcheck disable=SC1091
. venv/bin/activate
python3.14 -m pip install pipx
python3.14 -m pipx ensurepath
pipx install poetry==2.1.3
(cd "${REPO_DIR}/tests/integration/haf-local-tools" && poetry install)
echo -e "\e[0Ksection_end:$(date +%s):python_venv\r\e[0K"

cd "${REPO_DIR}/tests/integration/system/haf"
pytest --junitxml report_forking.xml -n "${PYTEST_NUMBER_OF_PROCESSES}" -k "lite_mode" -m "forking_only and not mirrornet" --timeout=600
test_end
