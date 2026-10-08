#!/usr/bin/env bash
# Runs inside the HAF image as the maintenance script of its entrypoint, after
# PostgreSQL is up (.aidev/run-checks.sh starts it):
#
#   /home/hived/docker_entrypoint.sh --execute-maintenance-script=/work/.aidev/hfm-functional.sh
#
# 1. Installs the candidate's hive_fork_manager extension SQL into PostgreSQL
#    the way Dockerfile.sql-overlay does (scripts/generate_extension_sql.sh, then
#    the control file's libhfm-<version>.so pointed at the image's own libhfm):
#    the image's C++ is the pinned base commit's, so only SQL is the candidate's.
# 2. Runs every ADD_SQL_FUNCTIONAL_TEST of tests/integration/functional/
#    {hive_fork_manager,query_supervisor} through tools/test.sh, as CI's ctest
#    does, HFM_TEST_JOBS at a time, and records one case per test.
#
# Environment: HFM_TEST_OUT (report dir, required), HFM_TEST_FILTER (optional
# extended regex over test paths), HFM_TEST_JOBS (default 4).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
src="$PWD"
out="${HFM_TEST_OUT:?HFM_TEST_OUT must name the report directory}"
mkdir -p "$out/hfm"
cases="$out/hfm-functional.tsv"; : > "$cases"
pg_version="${POSTGRES_VERSION:-18}"
version="aidev$(date +%s)"

echo "== installing candidate hive_fork_manager SQL as version $version"
ext="$(mktemp -d)"
bash scripts/generate_extension_sql.sh "$version" "$ext" "$pg_version" > "$out/hfm/generate.log" 2>&1 \
    || { cat "$out/hfm/generate.log"; exit 1; }
sudo -n cp -r "$ext"/. "/usr/share/postgresql/$pg_version/extension/" || exit 1
libdir="/usr/lib/postgresql/$pg_version/lib"
base_so=""
for so in "$libdir"/libhfm-*.so; do
    case "$so" in */libhfm-aidev*) ;; *) [ -e "$so" ] && { base_so="${so##*/}"; break; } ;; esac
done
[ -n "$base_so" ] || { echo "no libhfm-*.so in $libdir"; exit 1; }
sudo -n ln -sf "$base_so" "$libdir/libhfm-$version.so" || exit 1
sudo -n chmod 644 "/usr/share/postgresql/$pg_version/extension/"hive_fork_manager*.sql \
    "/usr/share/postgresql/$pg_version/extension/hive_fork_manager.control" || exit 1

# test.sh connects as these roles through localhost with password 'test'
cd tests/integration/functional || exit 1
port="${POSTGRES_PORT:-5432}"

run_one() {  # folder relpath
    local folder="$1" rel="$2" name log t0 rc
    name="${folder}/${rel%.sql}"
    log="$out/hfm/$(echo "$name" | tr '/' '.').log"
    t0=$(date +%s)
    tools/test.sh "$src/src/$folder" "$folder/$rel" "$src/scripts/" "$port" > "$log" 2>&1 < /dev/null
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
for folder in hive_fork_manager query_supervisor; do
    grep -E '^[[:space:]]*ADD_SQL_FUNCTIONAL_TEST\(' "$folder/CMakeLists.txt" \
        | sed -E 's/.*\( *([^ )]+).*/\1/' \
        | grep -E "${HFM_TEST_FILTER:-.}" \
        | sed "s#^#$folder #"
done > "$out/hfm/tests.txt"
for folder in hive_fork_manager query_supervisor; do
    awk '/SET_TESTS_PROPERTIES\(/ {blk=""; inb=1} inb {blk=blk" "$0} inb && /\)/ {if (blk ~ /RUN_SERIAL TRUE/) print blk; inb=0}' "$folder/CMakeLists.txt" \
        | grep -oE "test\.functional\.$folder\.[A-Za-z0-9_.]+" \
        | sed -E "s/^test\.functional\.$folder\.//; s#\.#/#; s/$/.sql/; s#^#$folder #"
done | sort -u > "$out/hfm/serial.txt"
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
