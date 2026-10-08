#!/usr/bin/env bash
# The step functions are called indirectly, through `step`.
# shellcheck disable=SC2317,SC2329
# The checks AIDEV's verification slots run (.aidev/project.yaml), as one junit
# report per suite: each named step is a test case, its log the failure body.
#
#   .aidev/run-checks.sh <suite> <step>...
#
#   - hfm-smoke       the hive_fork_manager functional tests under context_rewind/
#                     and app_api/ (.aidev/hfm-functional.sh), one junit case each
#   - hfm-functional  every hive_fork_manager and query_supervisor functional test
#                     ctest registers, one junit case each
#   - cxx-scope       a skipped case naming the candidate's changed C++/CMake/hive
#                     files: these checks run the candidate's SQL against the C++
#                     of the pinned HAF image, so such changes are not verified here
#
# The functional tests run inside the HAF image (this project's runtime) through
# its own entrypoint, which starts PostgreSQL and then runs .aidev/hfm-functional.sh
# as a maintenance script, as CI's hfm_functional_tests does. The entrypoint needs
# the image's sudo-capable `hived` user (uid 1000).
#
# Reports go to test-results/<suite>/: junit.xml (one case per step) plus
# hfm-functional.xml (one case per functional test).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

suite="${1:?usage: $0 <suite> <step>...}"; shift
out="test-results/$suite"
rm -rf "$out"; mkdir -p "$out"
cases="$out/cases.tsv"; : > "$cases"

status=0
# record CASES_FILE NAME RC SECONDS LOG
record() {
    if [ "$3" -eq 0 ]; then
        printf 'case\t%s\tpass\t%s\t\n' "$2" "$4" >> "$1"
    else
        printf 'case\t%s\tfail\t%s\texit %s\t%s\n' "$2" "$4" "$3" "$5" >> "$1"
    fi
}

step() {
    local name="$1"; shift
    local log="$out/$name.log" t0=$SECONDS rc=0
    echo "== $name" >&2
    "$@" > "$log" 2>&1 < /dev/null || rc=$?
    [ "$rc" -eq 0 ] || { status=1; tail -40 "$log" >&2; }
    record "$cases" "$name" "$rc" "$((SECONDS - t0))" "$log"
}

functional() {  # [filter]
    if [ "$(id -u)" != 1000 ] || ! sudo -n true 2>/dev/null; then
        echo "the HAF entrypoint needs the image's sudo-capable hived user (uid 1000); running as uid $(id -u)"
        return 1
    fi
    local rc=0
    HFM_TEST_OUT="$PWD/$out" HFM_TEST_FILTER="${1:-.}" HFM_TEST_JOBS="${HFM_TEST_JOBS:-8}" \
        /home/hived/docker_entrypoint.sh --execute-maintenance-script="$PWD/.aidev/hfm-functional.sh" || rc=$?
    if [ -f "$out/hfm-functional.tsv" ]; then
        python3 .aidev/junit_cases.py "$out/hfm-functional.xml" hfm-functional "$out/hfm-functional.tsv"
    fi
    return "$rc"
}

cxx_scope() {
    local changed="${AIDEV_CHANGED_FILES_FILE:-}" files
    if [ -z "$changed" ] || [ ! -f "$changed" ]; then
        printf 'case\tcxx-scope\tskip\t0\tchanged files unknown (no AIDEV_CHANGED_FILES_FILE)\n' >> "$cases"
        return
    fi
    files="$(grep -E '(\.(c|cc|cpp|cxx|h|hpp|ipp|in)$|CMakeLists\.txt$|\.cmake$|^hive$|^hive/)' "$changed" | tr '\n' ' ')"
    if [ -n "$files" ]; then
        echo "not verified here (C++ of the pinned HAF image is used): $files"
        printf 'case\tcxx-scope\tskip\t0\tC++/CMake changes not verified by these checks: %s\n' "${files:0:400}" >> "$cases"
    else
        printf 'case\tcxx-scope\tpass\t0\t\n' >> "$cases"
    fi
}

for s in "$@"; do
    case "$s" in
        hfm-smoke) step hfm-smoke functional '^(context_rewind|app_api)/' ;;
        hfm-functional) step hfm-functional functional ;;
        cxx-scope) cxx_scope ;;
        *) echo "unknown step: $s" >&2; exit 2 ;;
    esac
done
python3 .aidev/junit_cases.py "$out/junit.xml" "$suite" "$cases"
exit "$status"
