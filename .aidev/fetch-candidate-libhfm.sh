#!/usr/bin/env bash
# Puts the candidate's testnet libhfm into test-results/testnet-libhfm/, where
# .aidev/haf-system.sh installs it from, when hfm_functional has not run in this
# workspace (.aidev/README.md, The candidate's libhfm). Run it on the host, where
# docker is, before a run of the `haf_system` suite on its own, whose container
# has no network and no docker:
#
#   .aidev/fetch-candidate-libhfm.sh
#   aidev test run --slot full --suite haf_system -- --rerun haf-system::<module>.py::<test>
#
# Does nothing when test-results/testnet-libhfm/ already holds a libhfm built from
# this tree's src/hive_fork_manager/shared_lib. Otherwise it looks in this host's
# docker daemon, without pulling, for the per-commit source images AIDEV builds
# from .aidev/runtime/Dockerfile.source (`<registry>/aidev-runtime/haf-source:
# <source commit>-<recipe>`; `aidev test run --slot full` resolves the tree's own
# before it runs a suite). Those tagged with an ancestor of HEAD are tried closest
# first, at most HFM_FETCH_MAX_IMAGES (default 5) distinct images; the first whose
# /home/hived/aidev/testnet-libhfm/shared_lib.sha256 is this tree's hash is
# copied. Exit 0: the library is there. Exit 1: none was found (or it could not
# be written), with the reason on stderr.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

dest=test-results/testnet-libhfm
image_dir=/home/hived/aidev/testnet-libhfm
say() { echo "fetch-candidate-libhfm: $*" >&2; }

# the same hash .aidev/runtime/Dockerfile.source and .aidev/install-candidate-hfm.sh take
sources="$(find src/hive_fork_manager/shared_lib -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)"
if [ -f "$dest/libhfm.so" ] && [ "$sources" = "$(cat "$dest/shared_lib.sha256" 2>/dev/null)" ]; then
    say "$dest already holds the candidate's testnet libhfm"
    exit 0
fi
command -v docker > /dev/null || { say "no docker CLI here: run this on the host"; exit 1; }

# "<commits from HEAD> <image id> <repository:tag>" for each local source image of an ancestor of HEAD
candidates() {
    local ref id commit distance
    docker image ls --format '{{.Repository}}:{{.Tag}} {{.ID}}' 2>/dev/null \
        | grep -E '/aidev-runtime/haf-source:[0-9a-f]+-[0-9a-f]+ ' \
        | while read -r ref id; do
            commit="${ref##*:}"; commit="${commit%%-*}"
            git merge-base --is-ancestor "$commit" HEAD 2>/dev/null || continue
            distance="$(git rev-list --count "$commit..HEAD" 2>/dev/null)" || continue
            printf '%s %s %s\n' "$distance" "$id" "$ref"
        done | sort -n -k1,1 -s
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
tried=0
declare -A seen=()
while read -r _ id ref; do
    [ -z "${seen[$id]:-}" ] || continue
    seen[$id]=1
    [ "$tried" -lt "${HFM_FETCH_MAX_IMAGES:-5}" ] || break
    tried=$((tried + 1))
    container="$(docker create --pull never "$ref" true 2>/dev/null)" || continue
    rm -rf "$work/lib"
    docker cp -q "$container:$image_dir" "$work/lib" > /dev/null 2>&1
    docker rm "$container" > /dev/null 2>&1
    [ -f "$work/lib/libhfm.so" ] && [ "$sources" = "$(cat "$work/lib/shared_lib.sha256" 2>/dev/null)" ] || continue
    mkdir -p test-results
    rm -rf "$dest.tmp" && mkdir "$dest.tmp" \
        && cp "$work/lib/libhfm.so" "$work/lib/shared_lib.sha256" "$dest.tmp/" \
        && rm -rf "$dest" && mv "$dest.tmp" "$dest" \
        || { say "could not write $dest"; exit 1; }
    say "copied the candidate's testnet libhfm from $ref into $dest"
    exit 0
done < <(candidates)
say "no local aidev-runtime/haf-source image of an ancestor of HEAD holds a testnet libhfm built from this tree's shared_lib ($tried tried); \`aidev test run --slot full --suite hfm_functional\` builds or reuses that image and leaves the library in $dest"
exit 1
