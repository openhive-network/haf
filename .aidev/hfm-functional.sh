#!/usr/bin/env bash
# Runs inside the HAF image as the maintenance script of its entrypoint, after
# PostgreSQL is up (.aidev/run-checks.sh starts it):
#
#   /home/hived/docker_entrypoint.sh --execute-maintenance-script=/work/.aidev/hfm-functional.sh
#
# 1. Installs the candidate's hive_fork_manager extension SQL into PostgreSQL
#    (.aidev/install-candidate-hfm.sh: as Dockerfile.sql-overlay does, against the
#    image's own libhfm, which under aidev is built from the tree's own sources,
#    .aidev/README.md). When that SQL declares a C symbol the image's libhfm
#    lacks, records one failing case (hfm/libhfm-symbols) naming them and runs no
#    test.
# 2. Runs every ADD_SQL_FUNCTIONAL_TEST of tests/integration/functional/
#    {hive_fork_manager,query_supervisor} through tools/test.sh, as CI's ctest
#    does, HFM_TEST_JOBS at a time, and records one case per test.
# 3. Runs test_update_script.sh (hive_fork_manager/test_update_script) after
#    them, alone, as CI's ctest does after the functional tests.
#
# Environment: HFM_TEST_OUT (report dir, required), HFM_TEST_FILTER (optional
# Perl regex over the test names the cases are reported under,
# <folder>/<path without .sql>; selecting no test fails), HFM_TEST_JOBS (default 4).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
src="$PWD"
out="${HFM_TEST_OUT:?HFM_TEST_OUT must name the report directory}"
mkdir -p "$out/hfm"
cases="$out/hfm-functional.tsv"; : > "$cases"
rc=0
bash .aidev/install-candidate-hfm.sh "$out/hfm" || rc=$?
if [ "$rc" -eq 3 ]; then
    printf 'case\thfm/libhfm-symbols\tfail\t0\t%s\t%s\n' "$(< "$out/hfm/libhfm-symbols.log")" "$out/hfm/libhfm-symbols.log" >> "$cases"
    exit 1
fi
[ "$rc" -eq 0 ] || exit 1

# test.sh connects as these roles through localhost with password 'test'
cd tests/integration/functional || exit 1
port="${POSTGRES_PORT:-5432}"

run_one() {  # folder relpath
    local folder="$1" rel="$2" name log t0 rc
    name="${folder}/${rel%.*}"
    log="$out/hfm/$(echo "$name" | tr '/' '.').log"
    t0=$(date +%s)
    if [ "$rel" = test_update_script.sh ]; then
        # in a directory of its own: a failed schema check leaves its diff files in the working directory
        (cd "$(mktemp -d)" && "$src/tests/integration/functional/$folder/$rel" --haf_binaries_dir="$src") > "$log" 2>&1 < /dev/null
    else
        tools/test.sh "$src/src/$folder" "$folder/$rel" "$src/scripts/" "$port" > "$log" 2>&1 < /dev/null
    fi
    rc=$?
    if [ "$rc" -eq 0 ]; then
        printf 'case\t%s\tpass\t%s\t\n' "$name" "$(( $(date +%s) - t0 ))"
    else
        printf 'case\t%s\tfail\t%s\texit %s\t%s\n' "$name" "$(( $(date +%s) - t0 ))" "$rc" "$log"
    fi
}
export -f run_one
export src out port

# The ADD_SQL_FUNCTIONAL_TEST lines ctest would register (commented-out ones
# are not tests), and the ones a SET_TESTS_PROPERTIES block marks RUN_SERIAL,
# which ctest never runs alongside another test.
# PCRE because aidev renders re-run titles as a (?:a|b) alternation.
for folder in hive_fork_manager query_supervisor; do
    grep -E '^[[:space:]]*ADD_SQL_FUNCTIONAL_TEST\(' "$folder/CMakeLists.txt" \
        | sed -E "s/.*\\( *([^ )]+)\\.sql.*/$folder\\/\\1 \\1.sql/"
done > "$out/hfm/registered.txt"
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

echo "== running $(wc -l < "$out/hfm/parallel.txt") functional tests ${HFM_TEST_JOBS:-4} at a time, then $(wc -l < "$out/hfm/serial-selected.txt") RUN_SERIAL alone"
# shellcheck disable=SC2016 # $0/$1 are the inner bash's positional arguments
xargs -a "$out/hfm/parallel.txt" -r -P "${HFM_TEST_JOBS:-4}" -L 1 bash -c 'run_one "$0" "$1"' >> "$cases"
# shellcheck disable=SC2016 # as above
xargs -a "$out/hfm/serial-selected.txt" -r -P 1 -L 1 bash -c 'run_one "$0" "$1"' >> "$cases"
failed=$(grep -c $'\tfail\t' "$cases")
echo "== $(grep -c $'\tpass\t' "$cases") passed, $failed failed"
[ "$failed" -eq 0 ]
