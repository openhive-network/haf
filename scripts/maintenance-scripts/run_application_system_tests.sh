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

# Debug: show PATH and poetry location
echo "DEBUG: Current PATH: $PATH"
echo "DEBUG: Looking for poetry in common locations..."
ls -la /home/hived_admin/.local/bin/poetry 2>/dev/null || echo "DEBUG: /home/hived_admin/.local/bin/poetry not found"
ls -la /home/haf_admin/.local/bin/poetry 2>/dev/null || echo "DEBUG: /home/haf_admin/.local/bin/poetry not found"
which poetry 2>/dev/null || echo "DEBUG: poetry not in PATH"

# Add ci-base-image poetry location to PATH
export PATH="/home/hived_admin/.local/bin:$PATH"
echo "DEBUG: Updated PATH: $PATH"
which poetry || echo "DEBUG: poetry still not found after PATH update"

python3.14 -m venv venv/
# shellcheck disable=SC1091
. venv/bin/activate
echo "DEBUG: PATH after venv activation: $PATH"
which poetry || echo "DEBUG: poetry not found after venv activation"
(cd "${REPO_DIR}/tests/integration/haf-local-tools" && poetry install)
echo -e "\e[0Ksection_end:$(date +%s):python_venv\r\e[0K"


cd "${REPO_DIR}/tests/integration/system/applications"
pytest --junitxml report.xml -n "${PYTEST_NUMBER_OF_PROCESSES}" -m "not mirrornet" "${ARGS[@]}"

test_end
