#!/usr/bin/env bash
# Which HAF system tests (tests/integration/system/haf/) the candidate's change
# calls for: the `haf-system` suite's `select` in .aidev/project.yaml, and the
# selection .aidev/run-haf-system.sh runs.
#
#   .aidev/haf-system-select.sh
#
# The suite is change-scoped: it runs only for a change under
#
#   tests/integration/system/haf/   tests/integration/haf-local-tools/
#   src/hive_fork_manager/hived_api.sql   src/sql_serializer/
#
# or to the suite's own files (.aidev/haf-system-select.sh, haf-system.sh,
# run-haf-system.sh, haf-system-tests.txt, system_test_cases.py,
# install-candidate-hfm.sh, runtime/Dockerfile.system),
#
# and then only the tests that change matches: each changed test module
# (test_*.py directly in tests/integration/system/haf/) that still exists, plus,
# for any other path above, the core tests listed in .aidev/haf-system-tests.txt.
# Prints the selected modules, one per line, relative to tests/integration/system/haf/,
# and exits 0. For a change touching none of the paths it prints a `skipped:`
# reason as its last line and exits 77, which AIDEV reports as the suite skipped.
#
# The change is AIDEV_CHANGED_FILES_FILE (one path per line, `D<TAB>path` for a
# deleted one), else `git diff` from AIDEV_BASE_REF. When neither is available the
# change is unknown and the core tests are selected.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

tests_dir=tests/integration/system/haf
trigger='^(tests/integration/system/haf/|tests/integration/haf-local-tools/|src/hive_fork_manager/hived_api\.sql$|src/sql_serializer/|\.aidev/(haf-system-select\.sh|haf-system\.sh|run-haf-system\.sh|haf-system-tests\.txt|system_test_cases\.py|install-candidate-hfm\.sh|runtime/Dockerfile\.system)$)'
module="^$tests_dir/(test_[^/]*\\.py)\$"

core() {
    grep -vE '^[[:space:]]*(#|$)' .aidev/haf-system-tests.txt
}

changed_files() {
    if [ -n "${AIDEV_CHANGED_FILES_FILE:-}" ] && [ -f "$AIDEV_CHANGED_FILES_FILE" ]; then
        cat "$AIDEV_CHANGED_FILES_FILE"
    elif [ -n "${AIDEV_BASE_REF:-}" ] && git rev-parse --verify -q "$AIDEV_BASE_REF^{commit}" > /dev/null 2>&1; then
        git diff --no-renames --name-status "$AIDEV_BASE_REF" HEAD | awk -F'\t' '{print ($1 == "D" ? "D\t" $2 : $2)}'
    else
        return 1
    fi
}

if ! changes="$(changed_files)"; then
    echo "the change is unknown (no AIDEV_CHANGED_FILES_FILE or AIDEV_BASE_REF): selecting the core tests" >&2
    core
    exit 0
fi

selected=()
wants_core=0
while IFS= read -r line; do
    [ -n "$line" ] || continue
    path="${line#D$'\t'}"
    [[ "$path" =~ $trigger ]] || continue
    if [ "$path" = "$line" ] && [[ "$path" =~ $module ]] && [ -f "$path" ]; then
        selected+=("${BASH_REMATCH[1]}")
    else
        wants_core=1
    fi
done <<< "$changes"

if [ ${#selected[@]} -eq 0 ] && [ "$wants_core" -eq 0 ]; then
    echo "skipped: the change touches none of tests/integration/system/haf/, tests/integration/haf-local-tools/, src/hive_fork_manager/hived_api.sql, src/sql_serializer/, the suite's own .aidev/ files"
    exit 77
fi
{
    printf '%s\n' "${selected[@]}"
    [ "$wants_core" -eq 0 ] || core
} | grep -v '^$' | sort -u
