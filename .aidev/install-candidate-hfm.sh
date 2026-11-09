#!/usr/bin/env bash
# Installs the candidate's hive_fork_manager extension SQL into the HAF image's
# PostgreSQL the way Dockerfile.sql-overlay does: scripts/generate_extension_sql.sh,
# then the control file's libhfm-<version>.so pointed at the image's own libhfm.
# Runs inside the HAF image, as its sudo-capable hived user, from either suite's
# maintenance script (.aidev/hfm-functional.sh, .aidev/haf-system.sh).
#
#   [HFM_CANDIDATE_LIBHFM_DIR=DIR] .aidev/install-candidate-hfm.sh LOG_DIR
#
# HFM_CANDIDATE_LIBHFM_DIR names a directory holding a libhfm.so built from the
# candidate's sources for the image's network, and shared_lib.sha256, the hash of
# the src/hive_fork_manager/shared_lib it was built from (.aidev/runtime/Dockerfile.source).
# When that hash is this tree's, the library is installed as libhfm-<version>.so
# instead of the link to the image's own; otherwise, or without the directory, the
# image's libhfm is used, as it is when the variable is unset.
#
# Exit 0: installed, as the extension's default version. Exit 3: the candidate
# SQL declares C symbols the libhfm it is installed with lacks, so CREATE EXTENSION
# would fail in every test; the message naming them is printed and written to
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

candidate_so=""
candidate_dir="${HFM_CANDIDATE_LIBHFM_DIR:-}"
if [ -n "$candidate_dir" ] && [ -f "$candidate_dir/libhfm.so" ]; then
    # the same hash .aidev/runtime/Dockerfile.source takes of the sources it builds
    sources="$(find src/hive_fork_manager/shared_lib -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)"
    if [ "$sources" = "$(cat "$candidate_dir/shared_lib.sha256" 2>/dev/null)" ]; then
        candidate_so="$candidate_dir/libhfm.so"
        echo "== installing with the candidate's libhfm from $candidate_dir"
    else
        echo "== $candidate_dir/libhfm.so was built from other shared_lib sources than this tree's: installing with the image's $base_so"
    fi
elif [ -n "$candidate_dir" ]; then
    echo "== no candidate libhfm in $candidate_dir: installing with the image's $base_so"
fi

checked_so="${candidate_so:-$libdir/$base_so}"
missing="$(python3 .aidev/missing_c_symbols.py "$checked_so" "$ext"/hive_fork_manager*.sql)" || exit 1
if [ -n "$missing" ]; then
    echo "$checked_so lacks C symbols the candidate SQL declares: $(echo "$missing" | tr '\n' ' ')- it was not built from these sources (.aidev/README.md)" \
        | tee "$log_dir/libhfm-symbols.log"
    exit 3
fi

sudo -n cp -r "$ext"/. "/usr/share/postgresql/$pg_version/extension/" || exit 1
if [ -n "$candidate_so" ]; then
    sudo -n install -m 755 "$candidate_so" "$libdir/libhfm-$version.so" || exit 1
else
    sudo -n ln -sf "$base_so" "$libdir/libhfm-$version.so" || exit 1
fi
sudo -n chmod 644 "/usr/share/postgresql/$pg_version/extension/"hive_fork_manager*.sql \
    "/usr/share/postgresql/$pg_version/extension/hive_fork_manager.control" || exit 1
