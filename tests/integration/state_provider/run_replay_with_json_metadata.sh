#! /bin/bash

set -euo pipefail

CURRENT_PROJECT_DIR="$CI_PROJECT_DIR/tests/integration/state_provider"
# shellcheck source=./state_provider_common_run.sh
source "${CURRENT_PROJECT_DIR}/state_provider_common_run.sh" metadata
