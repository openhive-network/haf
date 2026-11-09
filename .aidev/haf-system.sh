#!/usr/bin/env bash
# Runs inside the `haf-system` suite's testnet HAF image as the maintenance script
# of its entrypoint, after PostgreSQL is up (.aidev/run-haf-system.sh starts it),
# as CI's haf_system_tests runs scripts/maintenance-scripts/run_haf_system_tests.sh:
#
# 1. Checks that the image's venv (.aidev/runtime/Dockerfile.system) was built
#    from the candidate's haf-local-tools poetry.lock; when it was not, records
#    one failing case (haf-system/environment) and runs no test.
# 2. Installs the candidate's hive_fork_manager SQL (.aidev/install-candidate-hfm.sh)
#    and recreates haf_block_log with it (the candidate's scripts/setup_db.sh, as
#    the entrypoint created it): every HafNode database is a copy of
#    haf_block_log, so this is the SQL the tests' hived connects to. It is
#    installed with the candidate's testnet libhfm in test-results/testnet-libhfm/,
#    taken from the source image built from this tree (.aidev/runtime/Dockerfile.source)
#    by .aidev/run-checks.sh, or on the host by .aidev/fetch-candidate-libhfm.sh,
#    else with the image's own libhfm.
# 3. Runs the selected tests with pytest under the testnet hived, HAF_SYSTEM_JOBS
#    at a time, and records one case per test (.aidev/system_test_cases.py).
#
# Environment: HAF_SYSTEM_OUT (report dir, required), HAF_SYSTEM_SELECTION (file
# of node ids or modules relative to tests/integration/system/haf/, required),
# HAF_SYSTEM_JOBS (default 4).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
src="$PWD"
out="${HAF_SYSTEM_OUT:?HAF_SYSTEM_OUT must name the report directory}"
selection="${HAF_SYSTEM_SELECTION:?HAF_SYSTEM_SELECTION must name the selected tests}"
cases="$out/haf-system.tsv"; : > "$cases"
mkdir -p "$out/setup"
venv=/opt/haf-system-venv
tests_dir=tests/integration/system/haf

fail_case() {  # NAME MESSAGE
    echo "$2" | tee "$out/setup/$1.log"
    printf 'case\thaf-system/%s\tfail\t0\t%s\t%s\n' "$1" "$2" "$out/setup/$1.log" >> "$cases"
    exit 1
}

if ! cmp -s "$venv/haf-local-tools.poetry.lock" tests/integration/haf-local-tools/poetry.lock; then
    fail_case environment "the image's venv ($venv) was not built from this tree's tests/integration/haf-local-tools/poetry.lock: rebuild and re-pin it (.aidev/README.md, The haf-system suite)"
fi

rc=0
HFM_CANDIDATE_LIBHFM_DIR="$src/test-results/testnet-libhfm" bash .aidev/install-candidate-hfm.sh "$out/setup" || rc=$?
[ "$rc" -ne 3 ] || fail_case libhfm-symbols "$(< "$out/setup/libhfm-symbols.log"). The candidate's testnet libhfm is built into the source image of this tree (.aidev/runtime/Dockerfile.source) and handed over in test-results/testnet-libhfm/ by the full slot's hfm_functional suite or by this suite's prepare step, .aidev/fetch-candidate-libhfm.sh: if that step did not run (aidev predating suite prepare steps, or the binding declaring it not yet approved), run it on the host first (it copies the library out of that image when the host's docker holds it), or \`aidev test run --slot full --suite hfm_functional\`, then re-run this suite"
[ "$rc" -eq 0 ] || fail_case install "installing the candidate's hive_fork_manager SQL failed (exit $rc)"
bash scripts/setup_db.sh --haf-db-admin=haf_admin --haf-db-name=haf_block_log > "$out/setup/setup_db.log" 2>&1 \
    || fail_case setup_db "recreating haf_block_log with the candidate's extension failed; see $out/setup/setup_db.log"

mapfile -t tests < "$selection"
echo "== running ${#tests[@]} selected system test(s) ${HAF_SYSTEM_JOBS:-4} at a time"
cd "$tests_dir" || exit 1
rc=0
# AIDEV reads every *.xml under the suite's artifacts as junit, so pytest's own report, whose ids
# lack the haf-system:: prefix known_failures.txt pardons, must not end in .xml.
raw_junit="$out/pytest.junit"
# The binaries and HELPY_* settings are CI's (ci_common.sh, .gitlab-ci.yml haf_system_tests), and
# so is the live-mode timeout (.gitlab-ci.yml's global variables; test_tools defaults to 30 s).
# A node that takes longer than one block interval (3 s) to start leaves witness production
# disabled, so the network's first block waits for InitNode's stale-production slot, which
# block_log_12_8 puts 30 s after launch: under load the 30 s default times out on it.
env PYTHONPATH="$src/tests/integration/haf-local-tools" PYTHONDONTWRITEBYTECODE=1 \
    TEST_TOOLS_NODE_DEFAULT_WAIT_FOR_LIVE_TIMEOUT=60 \
    DB_URL="postgresql://haf_admin@127.0.0.1:5432/haf_block_log" SETUP_SCRIPTS_PATH="$src/scripts" \
    HIVED_PATH=/home/hived/bin/hived CLI_WALLET_PATH=/home/hived/bin/cli_wallet \
    GET_DEV_KEY_PATH=/home/hived/bin/get_dev_key COMPRESS_BLOCK_LOG_PATH=/home/hived/bin/compress_block_log \
    BLOCK_LOG_UTIL_PATH=/home/hived/bin/block_log_util OP_BODY_FILTER_PATH=/home/hived/bin/op_body_filter \
    HELPY_COMMUNICATION_MAX_RETRIES=15 HELPY_COMMUNICATION_PERIOD_BETWEEN_RETRIES_SECS=10 \
    "$venv/bin/python" -m pytest -p no:cacheprovider --junitxml "$raw_junit" \
    -n "${HAF_SYSTEM_JOBS:-4}" -m "not mirrornet" "${tests[@]}" || rc=$?

# test_tools writes each module's nodes beside it; keep them with the report instead of in the checkout.
mkdir -p "$out/generated"
for dir in generated_during_* generated_by_package_fixtures; do
    [ -e "$dir" ] && mv "$dir" "$out/generated/"
done
if [ -f "$raw_junit" ]; then
    python3 "$src/.aidev/system_test_cases.py" "$raw_junit" "$out/tests" >> "$cases" || rc=1
fi
exit "$rc"
