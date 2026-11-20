#!/usr/bin/env bash
# Runs inside the HAF image as the maintenance script of its entrypoint, after
# PostgreSQL is up. .aidev/run-checks.sh starts it once it has installed the
# candidate's hive_fork_manager extension SQL (.aidev/install-candidate-hfm.sh: as
# Dockerfile.sql-overlay does, against the image's own libhfm, which under aidev
# is built from the tree's own sources, .aidev/README.md), so the entrypoint
# creates the extension in haf_block_log from it:
#
#   /home/hived/docker_entrypoint.sh --execute-maintenance-script=/work/.aidev/hfm-functional.sh
#
# 1. Checks that haf_block_log's hive_fork_manager is the candidate's version
#    (HFM_EXTENSION_VERSION); otherwise records one failing case
#    (hfm/extension-version) naming both versions and runs no test.
# 2. Runs every ADD_SQL_FUNCTIONAL_TEST of tests/integration/functional/
#    {hive_fork_manager,query_supervisor} through tools/test.sh, as CI's ctest
#    does, HFM_TEST_JOBS at a time, and records one case per test; with them
#    every ADD_EXAMPLES_FUNCTIONAL_TESTS of hive_fork_manager (the Python example
#    applications of src/hive_fork_manager/doc/examples, through
#    hive_fork_manager/test_examples.sh, which pip-installs their dependencies
#    into a venv of its own). AIDEV runs this container without a network, so
#    they come from the wheels .aidev/fetch-example-wheels.sh downloads on the
#    host into test-results/example-wheels/; where those are missing or do not
#    fit this image's Python and the package index is unreachable, each example
#    is recorded skipped with that reason.
# 3. Runs test_update_script.sh (hive_fork_manager/test_update_script) after
#    them, alone, as CI's ctest does after the functional tests.
#
# Environment: HFM_TEST_OUT (report dir, required), HFM_EXTENSION_VERSION (the
# version install-candidate-hfm.sh installed, required), HFM_TEST_FILTER (optional
# Perl regex over the test names the cases are reported under,
# <folder>/<path without .sql>; selecting no test fails), HFM_TEST_JOBS (default 4).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
src="$PWD"
out="${HFM_TEST_OUT:?HFM_TEST_OUT must name the report directory}"
mkdir -p "$out/hfm"
cases="$out/hfm-functional.tsv"; : > "$cases"
expected="${HFM_EXTENSION_VERSION:?HFM_EXTENSION_VERSION must name the installed candidate extension version}"
created="$(psql -U haf_admin -d haf_block_log -tAc "select extversion from pg_extension where extname = 'hive_fork_manager'" 2>&1)"
if [ "$created" != "$expected" ]; then
    echo "test image mismatch: haf_block_log's hive_fork_manager is version '$created', not the candidate's $expected that .aidev/install-candidate-hfm.sh installed: the entrypoint did not create the extension from this tree's SQL" \
        | tee "$out/hfm/extension-version.log"
    printf 'case\thfm/extension-version\tfail\t0\t%s\t%s\n' "$(< "$out/hfm/extension-version.log")" "$out/hfm/extension-version.log" >> "$cases"
    exit 1
fi
echo "== haf_block_log has hive_fork_manager $created, the candidate's"

# test.sh connects as these roles through localhost with password 'test'
cd tests/integration/functional || exit 1
port="${POSTGRES_PORT:-5432}"

run_one() {  # folder relpath
    local folder="$1" rel="$2" name log t0 rc
    name="${folder}/${rel%.*}"
    log="$out/hfm/$(echo "$name" | tr '/' '.').log"
    if [ "${rel##*.}" = py ] && [ -n "$examples_skip" ]; then
        printf 'case\t%s\tskip\t0\t%s\t%s\n' "$name" "$examples_skip" "$out/hfm/examples-index.log"
        return
    fi
    t0=$(date +%s)
    if [ "$rel" = test_update_script.sh ]; then
        # in a directory of its own: a failed schema check leaves its diff files in the working directory
        (cd "$(mktemp -d)" && "$src/tests/integration/functional/$folder/$rel" --haf_binaries_dir="$src") > "$log" 2>&1 < /dev/null
    elif [ "${rel##*.}" = py ]; then
        "$folder/test_examples.sh" "$src/src/$folder/doc/examples" "$folder/$rel" "$src/scripts/" "$port" > "$log" 2>&1 < /dev/null
    else
        tools/test.sh "$src/src/$folder" "$folder/$rel" "$src/scripts/" "$port" > "$log" 2>&1 < /dev/null
    fi
    rc=$?
    # the venv test_examples.sh leaves in the working tree
    [ "${rel##*.}" = py ] && rm -rf "./.test_examples_$(echo "$name" | tr '/' '_')"
    if [ "$rc" -eq 0 ]; then
        printf 'case\t%s\tpass\t%s\t\n' "$name" "$(( $(date +%s) - t0 ))"
    else
        printf 'case\t%s\tfail\t%s\texit %s\t%s\n' "$name" "$(( $(date +%s) - t0 ))" "$rc" "$log"
    fi
}
export -f run_one
export src out port

# The ADD_SQL_FUNCTIONAL_TEST and ADD_EXAMPLES_FUNCTIONAL_TESTS lines ctest would
# register (commented-out ones are not tests), and the ones a SET_TESTS_PROPERTIES
# block marks RUN_SERIAL, which ctest never runs alongside another test.
# PCRE because aidev renders re-run titles as a (?:a|b) alternation.
for folder in hive_fork_manager query_supervisor; do
    grep -E '^[[:space:]]*ADD_SQL_FUNCTIONAL_TEST\(' "$folder/CMakeLists.txt" \
        | sed -E "s/.*\\( *([^ )]+)\\.sql.*/$folder\\/\\1 \\1.sql/"
done > "$out/hfm/registered.txt"
grep -E '^[[:space:]]*ADD_EXAMPLES_FUNCTIONAL_TESTS\(' hive_fork_manager/CMakeLists.txt \
    | sed -E 's/.*\( *([^ )]+)\.py.*/hive_fork_manager\/\1 \1.py/' >> "$out/hfm/registered.txt"
# test_update_script, which CI's ctest runs after the functional tests; it updates the installed extension
# in place, so it runs alone (serial.txt)
update_test="hive_fork_manager test_update_script.sh"
if grep -qE '^ADD_TEST\( NAME test_update_script$' hive_fork_manager/CMakeLists.txt; then
    echo "hive_fork_manager/test_update_script test_update_script.sh" >> "$out/hfm/registered.txt"
fi
cut -d' ' -f1 "$out/hfm/registered.txt" | grep -P "${HFM_TEST_FILTER:-.}" \
    | awk 'NR == FNR {selected[$1]; next} $1 in selected {sub(/\/.*/, "", $1); print}' - "$out/hfm/registered.txt" > "$out/hfm/tests.txt"
if [ ! -s "$out/hfm/tests.txt" ]; then
    msg="no functional test matches HFM_TEST_FILTER '${HFM_TEST_FILTER:-.}'"
    echo "$msg" | tee "$out/hfm/selection.log"
    printf 'case\thfm/selection\tfail\t0\t%s\t%s\n' "$msg" "$out/hfm/selection.log" >> "$cases"
    exit 1
fi
for folder in hive_fork_manager query_supervisor; do
    awk '/SET_TESTS_PROPERTIES\(/ {blk=""; inb=1} inb {blk=blk" "$0} inb && /\)/ {if (blk ~ /RUN_SERIAL TRUE/) print blk; inb=0}' "$folder/CMakeLists.txt" \
        | grep -oE "test\.functional\.$folder\.[A-Za-z0-9_.]+" \
        | sed -E "s/^test\.functional\.$folder\.//; s#\.#/#; s/$/.sql/; s#^#$folder #"
done | sort -u > "$out/hfm/serial.txt"
echo "$update_test" >> "$out/hfm/serial.txt"
grep -vxF -f "$out/hfm/serial.txt" "$out/hfm/tests.txt" > "$out/hfm/parallel.txt"
grep -xF -f "$out/hfm/serial.txt" "$out/hfm/tests.txt" > "$out/hfm/serial-selected.txt"
# test_examples.sh pip-installs the examples' dependencies: from the wheels
# .aidev/fetch-example-wheels.sh left in the workspace when they resolve here
# without an index, otherwise from the index, probed once
examples_skip=""
wheels="$src/test-results/example-wheels"
requirements="$src/tests/integration/functional/hive_fork_manager/examples/requirements.txt"
if grep -q '\.py$' "$out/hfm/tests.txt"; then
    if [ -d "$wheels" ] \
       && python3 -m pip download --disable-pip-version-check --no-index --find-links "$wheels" -d "$(mktemp -d)" -r "$requirements" > "$out/hfm/examples-index.log" 2>&1; then
        echo "== the examples install their dependencies from $wheels"
        export HAF_EXAMPLES_WHEELS="$wheels"
    elif ! python3 -m pip download --no-deps --retries 0 --timeout 10 -d "$(mktemp -d)" 'pexpect>=4.9' >> "$out/hfm/examples-index.log" 2>&1; then
        if [ -d "$wheels" ]; then
            why="the wheels in test-results/example-wheels do not satisfy $(basename "$requirements") for this image's $(python3 --version 2>&1)"
        elif [ -f "$src/test-results/example-wheels.failed" ]; then
            why="the host could not fetch their wheels: $(head -c 400 "$src/test-results/example-wheels.failed")"
        else
            why="no wheels in test-results/example-wheels (.aidev/fetch-example-wheels.sh, the full slot's hfm_functional prepare step, did not run here)"
        fi
        examples_skip="the package index ${PIP_INDEX_URL:-https://pypi.org/simple} is unreachable from this container and $why, so test_examples.sh cannot install the examples' dependencies, which the image lacks (pexpect, psycopg[binary], sqlalchemy, jinja2)"
    fi
fi
export examples_skip

echo "== running $(wc -l < "$out/hfm/parallel.txt") functional tests ${HFM_TEST_JOBS:-4} at a time, then $(wc -l < "$out/hfm/serial-selected.txt") RUN_SERIAL alone"
# shellcheck disable=SC2016 # $0/$1 are the inner bash's positional arguments
xargs -a "$out/hfm/parallel.txt" -r -P "${HFM_TEST_JOBS:-4}" -L 1 bash -c 'run_one "$0" "$1"' >> "$cases"
# shellcheck disable=SC2016 # as above
xargs -a "$out/hfm/serial-selected.txt" -r -P 1 -L 1 bash -c 'run_one "$0" "$1"' >> "$cases"
failed=$(grep -c $'\tfail\t' "$cases")
echo "== $(grep -c $'\tpass\t' "$cases") passed, $failed failed, $(grep -c $'\tskip\t' "$cases") skipped"
[ "$failed" -eq 0 ]
