#!/usr/bin/env bash
# Puts the candidate's testnet libhfm into test-results/testnet-libhfm/, where
# .aidev/haf-system.sh installs it from, when hfm_functional has not run in this
# workspace (.aidev/README.md, The candidate's libhfm). It is the `haf_system`
# suite's `prepare` step (.aidev/project.yaml): aidev runs it on the host, where
# docker and the registry are, before the suite, whose container has no network
# and no docker, both in the `full` slot and in a run of the suite on its own. It
# can also be run by hand the same way.
#
# Does nothing when test-results/testnet-libhfm/ already holds a libhfm built from
# this tree's src/hive_fork_manager/shared_lib. Otherwise it tries, in order:
#
# 1. The per-commit source images AIDEV builds from .aidev/runtime/Dockerfile.source
#    (`<registry>/aidev-runtime/haf-source:<source commit>-<recipe>`), in this
#    host's docker daemon, without pulling. Those tagged with an ancestor of HEAD
#    are tried closest first, at most HFM_FETCH_MAX_IMAGES (default 5) distinct
#    images; one whose /home/hived/aidev/testnet-libhfm/shared_lib.sha256 is this
#    tree's hash is copied. AIDEV_SUITE_RUNTIME_IMAGE, which aidev sets for a
#    prepare step, is the suite's own pinned image, not a source image, so it is
#    not used.
# 2. CI's testnet images, `registry.gitlab.syncad.com/hive/haf/testnet:<commit[:8]>`
#    (HFM_FETCH_CI_REPOSITORY), which CI builds alongside the `hive/haf:<commit[:8]>`
#    image aidev then runs instead of building a source image. They carry no
#    shared_lib.sha256, so only commits of HEAD that changed CI's source paths
#    (scripts/ci-helpers/source-patterns.sh, plus tests/unit/ for testnet) and whose
#    src/hive_fork_manager/shared_lib git tree is HEAD's are tried, newest first, at
#    most HFM_FETCH_MAX_IMAGES, and only when the working tree's shared_lib is
#    HEAD's. An image not on the host is pulled, bounded by HFM_FETCH_PULL_TIMEOUT
#    seconds (default 600; the prepare step's own bound is 900). Its libhfm is
#    copied only when the commit it was built from (its
#    org.opencontainers.image.revision label), when this checkout has it, has that
#    tree too.
#
# A library from other shared_lib sources is never copied. Exit 0: the library is
# there (test-results/testnet-libhfm/origin names the image it came from). Exit 1:
# none was found (or it could not be written), with what was tried on stderr, so
# the suite does not run (a prepare failure) rather than fail later as
# haf-system/libhfm-symbols.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

dest=test-results/testnet-libhfm
shared_lib=src/hive_fork_manager/shared_lib
image_dir=/home/hived/aidev/testnet-libhfm
ci_repository="${HFM_FETCH_CI_REPOSITORY:-registry.gitlab.syncad.com/hive/haf/testnet}"
max_images="${HFM_FETCH_MAX_IMAGES:-5}"
say() { echo "fetch-candidate-libhfm: $*" >&2; }

# the same hash .aidev/runtime/Dockerfile.source and .aidev/install-candidate-hfm.sh take
sources="$(find "$shared_lib" -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)"
if [ -f "$dest/libhfm.so" ] && [ "$sources" = "$(cat "$dest/shared_lib.sha256" 2>/dev/null)" ]; then
    say "$dest already holds the candidate's testnet libhfm"
    exit 0
fi
command -v docker > /dev/null || { say "no docker CLI here: run this on the host"; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# hand_over LIBRARY ORIGIN: installs LIBRARY, built from this tree's shared_lib, into $dest and exits
hand_over() {
    mkdir -p test-results
    rm -rf "$dest.tmp" && mkdir "$dest.tmp" \
        && cp "$1" "$dest.tmp/libhfm.so" \
        && echo "$sources" > "$dest.tmp/shared_lib.sha256" \
        && echo "$2" > "$dest.tmp/origin" \
        && rm -rf "$dest" && mv "$dest.tmp" "$dest" \
        || { say "could not write $dest"; exit 1; }
    say "copied the candidate's testnet libhfm from $2 into $dest"
    exit 0
}

# copy_out IMAGE PATH: copies PATH out of the local IMAGE to $work/out
copy_out() {
    local container
    rm -rf "$work/out"
    container="$(docker create --pull never "$1" true 2>/dev/null)" || return 1
    docker cp -q "$container:$2" "$work/out" > /dev/null 2>&1
    docker rm "$container" > /dev/null 2>&1
    [ -e "$work/out" ]
}

# "<commits from HEAD> <image id> <repository:tag>" for each local source image of an ancestor of HEAD
local_candidates() {
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

tried=0
declare -A seen=()
while read -r _ id ref; do
    [ -z "${seen[$id]:-}" ] || continue
    seen[$id]=1
    [ "$tried" -lt "$max_images" ] || break
    tried=$((tried + 1))
    copy_out "$ref" "$image_dir" && [ -f "$work/out/libhfm.so" ] \
        && [ "$sources" = "$(cat "$work/out/shared_lib.sha256" 2>/dev/null)" ] || continue
    hand_over "$work/out/libhfm.so" "$ref"
done < <(local_candidates)
if [ "$tried" -eq 0 ]; then
    local_result="no local aidev-runtime/haf-source:<commit>-<recipe> image of HEAD or an ancestor"
else
    local_result="none of the $tried closest local aidev-runtime/haf-source images of an ancestor of HEAD holds one"
fi

tree_of() { git rev-parse --verify -q "$1:$shared_lib" 2>/dev/null; }
head_tree="$(tree_of HEAD)"

# commits of HEAD that CI tags images with and whose shared_lib tree is HEAD's, newest first
ci_candidates() {
    local patterns commit
    IFS=',' read -ra patterns <<< "$(scripts/ci-helpers/source-patterns.sh)"
    git rev-list --max-count=50 HEAD -- "${patterns[@]}" tests/unit/ \
        | while read -r commit; do
            [ "$(tree_of "$commit")" = "$head_tree" ] && echo "$commit"
        done
}

# try_ci_image REF: copies REF's libhfm to $work/out and prints the commit it was
# built from; otherwise prints why not and fails
try_ci_image() {
    local ref="$1" revision libs started
    if ! docker image inspect "$ref" > /dev/null 2>&1; then
        timeout 60 docker manifest inspect "$ref" > /dev/null 2>&1 || { echo "not in the registry"; return 1; }
        started=$SECONDS
        timeout "${HFM_FETCH_PULL_TIMEOUT:-600}" docker pull -q "$ref" > /dev/null 2> "$work/pull.err" \
            || { echo "pull failed after $((SECONDS - started)) s: $(tail -n 1 "$work/pull.err")"; return 1; }
        say "pulled $ref in $((SECONDS - started)) s"
    fi
    revision="$(docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$ref" 2>/dev/null)"
    if [ -n "$revision" ] && git cat-file -e "$revision^{commit}" 2>/dev/null \
        && [ "$(tree_of "$revision")" != "$head_tree" ]; then
        echo "built from $revision, whose shared_lib tree $(tree_of "$revision") is not HEAD's"
        return 1
    fi
    libs="$(docker run --rm --pull never --network none --entrypoint /bin/sh "$ref" \
        -c 'ls /usr/lib/postgresql/*/lib/libhfm-*.so' 2>/dev/null)"
    [ "$(printf '%s\n' "$libs" | grep -c .)" -eq 1 ] || { echo "no single libhfm-*.so: ${libs:-none}"; return 1; }
    copy_out "$ref" "$libs" && [ -f "$work/out" ] || { echo "could not copy $libs out of it"; return 1; }
    echo "${revision:-an unlabelled commit}"
}

ci_tried=()
if [ -n "$(git status --porcelain --untracked-files=all -- "$shared_lib")" ]; then
    ci_result="CI testnet images not tried: the working tree's $shared_lib differs from HEAD's, so no commit's image was built from it"
else
    while read -r commit; do
        [ "${#ci_tried[@]}" -lt "$max_images" ] || break
        ref="$ci_repository:${commit:0:8}"
        if outcome="$(try_ci_image "$ref")"; then
            say "$ref: ${commit:0:8} and HEAD have the same $shared_lib tree ($head_tree); the image was built from $outcome"
            hand_over "$work/out" "$ref $(docker image inspect --format '{{ .Id }}' "$ref" 2>/dev/null) (built from $outcome)"
        fi
        ci_tried+=("$ref: $outcome")
    done < <(ci_candidates)
    if [ "${#ci_tried[@]}" -eq 0 ]; then
        ci_result="no CI testnet image tried: no recent commit of HEAD that changed CI's source paths has HEAD's $shared_lib tree ($head_tree)"
    else
        ci_result="none of the CI testnet images of commits with HEAD's $shared_lib tree ($head_tree) had one ($(IFS=';'; echo "${ci_tried[*]}"))"
    fi
fi

say "missing testnet libhfm: nothing built from this tree's shared_lib ($sources) to hand to haf_system at HEAD ($(git rev-parse --short HEAD)): $local_result; $ci_result; \`aidev test run --slot full --suite hfm_functional\` in an aidev-built source image leaves the library in $dest"
exit 1
