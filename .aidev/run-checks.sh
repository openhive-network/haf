#!/usr/bin/env bash
# The step functions are called indirectly, through `step`.
# shellcheck disable=SC2317,SC2329
# The checks AIDEV's verification slots run (.aidev/project.yaml), as one junit
# report per suite: each named step is a test case, its log the failure body.
#
#   .aidev/run-checks.sh <suite> <step>... [--rerun <id>...]
#
#   - hfm-smoke       the hive_fork_manager functional tests under context_rewind/
#                     and app_api/ (.aidev/hfm-functional.sh), one junit case each
#   - hfm-functional  every hive_fork_manager and query_supervisor functional test
#                     ctest registers, and test_update_script, one junit case each
#   - cxx-scope       a skipped case naming the candidate's changed C++/CMake/hive
#                     files other than libhfm's and libquery_supervisor's sources:
#                     the image is built with those two libraries from the
#                     candidate's sources (.aidev/runtime/Dockerfile.source), but
#                     hived and the C++ unit tests are not run here
#
# The functional tests run inside the HAF image (this project's runtime) through
# its own entrypoint, which starts PostgreSQL and then runs .aidev/hfm-functional.sh
# as a maintenance script, as CI's hfm_functional_tests does. The entrypoint needs
# the image's sudo-capable `hived` user (uid 1000).
#
# Reports go to test-results/<suite>/: junit.xml (one case per step) plus
# hfm-functional.xml (one case per functional test). A step whose failures
# hfm-functional.xml records is reported skipped in junit.xml, pointing there
# (.aidev/junit_cases.py), so a failing test is reported once, under its own id.
#
# --rerun runs only the named functional tests, through the listed step that
# owns them (cxx-scope is not run), and reports to test-results/<suite>/rerun/<n>/,
# leaving the run it re-runs intact. That is under the slot's declared artifacts
# path, so aidev's causality check reads a re-run on the base tree as a verdict:
# an id its report does not name is absent on base. aidev reads a report only
# when written after the run it grades started, and reads and keeps the run's
# own reports before re-running any of its failures, so a re-run's report never
# joins them; the next run's rm -rf removes it. Each argument is a reported test id
# (hfm-functional::hive_fork_manager/<folder>/<test>, with or without the
# `hfm-functional::`), a test's .sql path, or a Perl regex over the ids' names
# (aidev's rendered `(?:a|b)` titles). The exit status is 0 only when every
# selected test passed and every named id was found.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

suite="${1:?usage: $0 <suite> <step>... [--rerun <id>...]}"; shift
steps=()
while [ $# -gt 0 ] && [ "$1" != --rerun ]; do steps+=("$1"); shift; done
rerun=()
if [ $# -gt 0 ]; then
    shift
    rerun=("$@")
    [ ${#rerun[@]} -gt 0 ] || { echo "--rerun needs at least one test id" >&2; exit 2; }
fi

if [ ${#rerun[@]} -eq 0 ]; then
    out="test-results/$suite"
    rm -rf "$out"; mkdir -p "$out"
else
    mkdir -p "test-results/$suite/rerun"
    n=1
    until mkdir "test-results/$suite/rerun/$n" 2>/dev/null; do n=$((n + 1)); done
    out="test-results/$suite/rerun/$n"
fi
cases="$out/cases.tsv"; : > "$cases"

status=0
# record CASES_FILE NAME RC SECONDS LOG [TESTS_JUNIT]
record() {
    if [ "$3" -eq 0 ]; then
        printf 'case\t%s\tpass\t%s\t\n' "$2" "$4" >> "$1"
    else
        printf 'case\t%s\tfail\t%s\texit %s\t%s\t%s\n' "$2" "$4" "$3" "$5" "${6:-}" >> "$1"
    fi
}

step() {  # NAME TESTS_JUNIT COMMAND...  (TESTS_JUNIT: the per-test junit it writes, or "")
    local name="$1" tests_junit="$2"; shift 2
    local log="$out/$name.log" t0=$SECONDS rc=0
    echo "== $name" >&2
    "$@" > "$log" 2>&1 < /dev/null || rc=$?
    [ "$rc" -eq 0 ] || { status=1; tail -40 "$log" >&2; }
    record "$cases" "$name" "$rc" "$((SECONDS - t0))" "$log" "$tests_junit"
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
    files="$(grep -E '(\.(c|cc|cpp|cxx|h|hpp|ipp|in)$|CMakeLists\.txt$|\.cmake$|^hive$|^hive/)' "$changed" \
        | grep -vE '^src/(hive_fork_manager/shared_lib|query_supervisor)/' | tr '\n' ' ')"
    if [ -n "$files" ]; then
        echo "not verified here (only libhfm and libquery_supervisor are the candidate's build): $files"
        printf 'case\tcxx-scope\tskip\t0\tC++/CMake changes not verified by these checks: %s\n' "${files:0:400}" >> "$cases"
    else
        printf 'case\tcxx-scope\tpass\t0\t\n' >> "$cases"
    fi
}

# The functional tests' ids are hfm-functional::<name>, <name> being what
# HFM_TEST_FILTER matches; a literal id becomes an exact match, anything else
# is taken as a regex over names.
literal_id='^[A-Za-z0-9_./-]+$'
rerun_name() {  # ARG
    local arg="${1#hfm-functional::}"
    arg="${arg#tests/integration/functional/}"
    printf '%s' "${arg%.sql}"
}

rerun_filter() {
    local arg name alternatives=()
    for arg in "${rerun[@]}"; do
        name="$(rerun_name "$arg")"
        if [[ "$name" =~ $literal_id ]]; then
            alternatives+=("\\Q$name\\E")
        else
            alternatives+=("(?:$name)")
        fi
    done
    local IFS='|'
    printf '^(?:%s)$' "${alternatives[*]}"
}

# A literal id the re-run did not run fails it: its exit status would
# otherwise pardon a test that never ran.
rerun_unmatched() {
    local arg name missing=()
    for arg in "${rerun[@]}"; do
        name="$(rerun_name "$arg")"
        [[ "$name" =~ $literal_id ]] || continue
        grep -qP "^case\t\Q$name\E\t" "$out/hfm-functional.tsv" 2>/dev/null || missing+=("$name")
    done
    [ ${#missing[@]} -eq 0 ] && return
    status=1
    echo "re-run ids that name no functional test: ${missing[*]}" >&2
    printf 'case\trerun-ids\tfail\t0\tre-run ids that name no functional test: %s\n' "${missing[*]}" >> "$cases"
}

# An image built by .aidev/runtime/Dockerfile.source also carries libhfm built for the testnet from these
# sources. The haf_system suite runs in its own testnet image, whose libhfm was not built from them, so it is
# handed over through the workspace (.aidev/haf-system.sh); the `full` slot runs hfm_functional before haf_system.
testnet_libhfm=/home/hived/aidev/testnet-libhfm
if [ -f "$testnet_libhfm/libhfm.so" ]; then
    rm -rf test-results/testnet-libhfm
    mkdir -p test-results/testnet-libhfm \
        && cp "$testnet_libhfm/libhfm.so" "$testnet_libhfm/shared_lib.sha256" test-results/testnet-libhfm/ \
        || echo "could not hand the candidate's testnet libhfm to the haf_system suite: it will run the image's own" >&2
fi

declare -A step_filter=(
    [hfm-smoke]='^hive_fork_manager/(context_rewind|app_api)/'
    [hfm-functional]='.'
)
for s in "${steps[@]}"; do
    case "$s" in
        hfm-smoke|hfm-functional|cxx-scope) ;;
        *) echo "unknown step: $s" >&2; exit 2 ;;
    esac
done

if [ ${#rerun[@]} -eq 0 ]; then
    for s in "${steps[@]}"; do
        case "$s" in
            hfm-smoke|hfm-functional) step "$s" "$out/hfm-functional.xml" functional "${step_filter[$s]}" ;;
            cxx-scope) cxx_scope ;;
        esac
    done
else
    owner=""
    for s in "${steps[@]}"; do
        [ -n "${step_filter[$s]:-}" ] && { owner="$s"; break; }
    done
    [ -n "$owner" ] || { echo "--rerun: none of the steps (${steps[*]}) runs functional tests" >&2; exit 2; }
    step "$owner" "$out/hfm-functional.xml" functional "(?=${step_filter[$owner]})$(rerun_filter)"
    rerun_unmatched
fi
python3 .aidev/junit_cases.py "$out/junit.xml" "$suite" "$cases"
exit "$status"
