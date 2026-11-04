#!/usr/bin/env bash
# Installs the candidate's hive_fork_manager extension SQL into the HAF image's
# PostgreSQL the way Dockerfile.sql-overlay does: scripts/generate_extension_sql.sh,
# then the control file's libhfm-<version>.so pointed at the image's own libhfm.
# Runs inside the HAF image, as its sudo-capable hived user, from either suite's
# maintenance script (.aidev/hfm-functional.sh, .aidev/haf-system.sh).
#
#   .aidev/install-candidate-hfm.sh LOG_DIR
#
# Exit 0: installed, as the extension's default version. Exit 3: the candidate
# SQL declares C symbols the image's libhfm lacks, so CREATE EXTENSION would fail
# in every test; the message naming them is printed and written to
# LOG_DIR/libhfm-symbols.log, and nothing is installed. Any other status: the
# install failed (generate_extension_sql.sh's output is in LOG_DIR/generate.log).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
log_dir="${1:?usage: $0 LOG_DIR}"
mkdir -p "$log_dir"
pg_version="${POSTGRES_VERSION:-18}"
version="aidev$(date +%s)"

echo "== installing candidate hive_fork_manager SQL as version $version"
ext="$(mktemp -d)"
bash scripts/generate_extension_sql.sh "$version" "$ext" "$pg_version" > "$log_dir/generate.log" 2>&1 \
    || { cat "$log_dir/generate.log"; exit 1; }
libdir="/usr/lib/postgresql/$pg_version/lib"
base_so=""
for so in "$libdir"/libhfm-*.so; do
    case "$so" in */libhfm-aidev*) ;; *) [ -e "$so" ] && { base_so="${so##*/}"; break; } ;; esac
done
[ -n "$base_so" ] || { echo "no libhfm-*.so in $libdir"; exit 1; }

missing="$(python3 .aidev/missing_c_symbols.py "$libdir/$base_so" "$ext"/hive_fork_manager*.sql)" || exit 1
if [ -n "$missing" ]; then
    echo "$base_so lacks C symbols the candidate SQL declares: $(echo "$missing" | tr '\n' ' ')- the image was not built from these sources (.aidev/README.md)" \
        | tee "$log_dir/libhfm-symbols.log"
    exit 3
fi

sudo -n cp -r "$ext"/. "/usr/share/postgresql/$pg_version/extension/" || exit 1
sudo -n ln -sf "$base_so" "$libdir/libhfm-$version.so" || exit 1
sudo -n chmod 644 "/usr/share/postgresql/$pg_version/extension/"hive_fork_manager*.sql \
    "/usr/share/postgresql/$pg_version/extension/hive_fork_manager.control" || exit 1
