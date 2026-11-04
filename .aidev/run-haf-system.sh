#!/usr/bin/env bash
# The `haf-system` suite of the `full` slot (.aidev/project.yaml): the HAF system
# tests (tests/integration/system/haf/) the candidate's change selects, run in the
# suite's own image, the testnet HAF image with the tests' Python environment
# (.aidev/runtime/Dockerfile.system).
#
#   .aidev/run-haf-system.sh [--rerun <id>...]
#
# Selects the tests with .aidev/haf-system-select.sh; when the change calls for
# none it writes a skipped case and exits 77, with the reason as its last line.
# Otherwise it runs them through the image's entrypoint, which starts PostgreSQL
# and then runs .aidev/haf-system.sh as a maintenance script, as CI's
# haf_system_tests does. The entrypoint needs the image's sudo-capable `hived`
# user (uid 1000).
#
# Writes test-results/haf-system/junit.xml: one case per test, named by its node
# id (reported as haf-system::test_x.py::test_y), plus a failing haf-system/<step>
# case when setting up failed or the run failed with no failing test recorded.
#
# --rerun runs only the named tests, each a reported id (with or without the
# `haf-system::`) or a pytest node id relative to tests/integration/system/haf/,
# and reports to test-results/haf-system/rerun/<n>/, as .aidev/run-checks.sh
# --rerun does. A named id pytest cannot find fails the re-run.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

rerun=()
if [ $# -gt 0 ]; then
    [ "$1" = --rerun ] && [ $# -gt 1 ] || { echo "usage: $0 [--rerun <id>...]" >&2; exit 2; }
    shift
    rerun=("$@")
fi

if [ ${#rerun[@]} -eq 0 ]; then
    out="test-results/haf-system"
    rm -rf "$out"; mkdir -p "$out"
else
    mkdir -p test-results/haf-system/rerun
    n=1
    until mkdir "test-results/haf-system/rerun/$n" 2>/dev/null; do n=$((n + 1)); done
    out="test-results/haf-system/rerun/$n"
fi
out="$PWD/$out"
cases="$out/cases.tsv"; : > "$cases"
selection="$out/selection.txt"

report() {
    python3 .aidev/junit_cases.py "$out/junit.xml" haf-system "$cases"
}

if [ ${#rerun[@]} -eq 0 ]; then
    rc=0
    .aidev/haf-system-select.sh > "$selection" || rc=$?
    if [ "$rc" -eq 77 ]; then
        reason="$(tail -1 "$selection")"
        printf 'case\thaf-system/selection\tskip\t0\t%s\n' "${reason#skipped: }" >> "$cases"
        report
        echo "$reason"
        exit 77
    fi
    [ "$rc" -eq 0 ] || { echo "selecting the system tests failed (exit $rc)" >&2; exit 1; }
else
    for id in "${rerun[@]}"; do printf '%s\n' "${id#haf-system::}"; done > "$selection"
fi
echo "== selected: $(tr '\n' ' ' < "$selection")" >&2

t0=$SECONDS
rc=0
if [ "$(id -u)" != 1000 ] || ! sudo -n true 2>/dev/null; then
    echo "the HAF entrypoint needs the image's sudo-capable hived user (uid 1000); running as uid $(id -u)" > "$out/run.log"
    rc=1
else
    # CI's PG_ACCESS_LOCAL_TRUST (.gitlab-ci.yml): the tests connect as haf_admin through 127.0.0.1
    PG_ACCESS=$'local all all trust\nhost all all 127.0.0.1/32 trust\nhost all all ::1/128 trust' \
    HAF_SYSTEM_OUT="$out" HAF_SYSTEM_SELECTION="$selection" HAF_SYSTEM_JOBS="${HAF_SYSTEM_JOBS:-4}" \
        /home/hived/docker_entrypoint.sh --execute-maintenance-script="$PWD/.aidev/haf-system.sh" \
        > "$out/run.log" 2>&1 < /dev/null || rc=$?
fi
[ -f "$out/haf-system.tsv" ] && cat "$out/haf-system.tsv" >> "$cases"
if [ "$rc" -ne 0 ]; then
    tail -40 "$out/run.log" >&2
    if ! grep -q $'\tfail\t' "$cases"; then
        printf 'case\thaf-system/run\tfail\t%s\texit %s\t%s\n' "$((SECONDS - t0))" "$rc" "$out/run.log" >> "$cases"
    fi
fi
report
echo "== $(grep -c $'\tpass\t' "$cases") passed, $(grep -c $'\tfail\t' "$cases") failed" >&2
exit "$rc"
