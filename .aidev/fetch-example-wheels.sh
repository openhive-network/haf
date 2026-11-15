#!/usr/bin/env bash
# Puts wheels of the hive_fork_manager example applications' dependencies
# (tests/integration/functional/hive_fork_manager/examples/requirements.txt) into
# test-results/example-wheels/, where .aidev/hfm-functional.sh hands them to
# test_examples.sh to install without a package index (.aidev/README.md, The
# examples' dependencies). It is the `full` slot's `hfm_functional` suite's
# `prepare` step (.aidev/project.yaml): aidev runs it on the host, where docker and
# the network are, before the suite, whose container has neither. It can also be
# run by hand the same way.
#
# The wheels are downloaded by the Python and pip of the suite's image
# (AIDEV_SUITE_RUNTIME_IMAGE, which aidev sets for a prepare step; otherwise
# environment.image of .aidev/project.yaml), run on the host's network, so they are
# built for that Python. A CI-built or aidev-built source image the suite may run
# in instead has the same Ubuntu and Python; hfm-functional.sh checks the wheels
# resolve offline there before using them. Does nothing when
# test-results/example-wheels/ already holds them for these requirements and
# that image.
#
# Exit 0 in every case but a broken checkout: when the wheels cannot be fetched
# (no docker, no registry, no package index), the reason is written to
# test-results/example-wheels.failed and printed on stderr, and the examples are
# recorded skipped with it rather than the suite not running.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

dest=test-results/example-wheels
failed=test-results/example-wheels.failed
requirements=tests/integration/functional/hive_fork_manager/examples/requirements.txt
say() { echo "fetch-example-wheels: $*" >&2; }

[ -f "$requirements" ] || { say "no $requirements in this checkout"; exit 1; }
image="${AIDEV_SUITE_RUNTIME_IMAGE:-}"
if [ -z "$image" ]; then
    image="$(sed -nE '/^environment:/,/^[^ #]/ s/^  image: *"?([^" ]+)"?.*/\1/p' .aidev/project.yaml | head -n 1)"
fi
stamp="$(sha256sum < "$requirements" | cut -d' ' -f1) $image"
if [ -f "$dest/stamp" ] && [ "$stamp" = "$(cat "$dest/stamp")" ]; then
    say "$dest already holds the examples' wheels for $image"
    exit 0
fi

give_up() {
    mkdir -p test-results
    rm -rf "$dest" "$dest.tmp"
    printf '%s\n' "$1" > "$failed"
    say "$1"
    exit 0
}
[ -n "$image" ] || give_up "no runtime image to download the examples' wheels with (AIDEV_SUITE_RUNTIME_IMAGE unset, no environment.image in .aidev/project.yaml)"
command -v docker > /dev/null || give_up "no docker CLI on this host to download the examples' wheels with"

mkdir -p test-results
rm -rf "$dest.tmp" && mkdir "$dest.tmp" || give_up "could not create $dest.tmp"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
# The requirements go in on stdin and the wheels come out as a tar on stdout, so
# no bind mount depends on the daemon seeing this checkout's path.
# shellcheck disable=SC2016 # expanded by the container's shell
if ! docker run --rm -i -e HOME=/tmp -e PIP_INDEX_URL --entrypoint /bin/sh "$image" \
        -c 'cat > /tmp/requirements.txt && mkdir /tmp/wheels \
            && python3 -m pip download --disable-pip-version-check -q -d /tmp/wheels -r /tmp/requirements.txt >&2 \
            && python3 --version >&2 && tar -C /tmp/wheels -cf - .' \
        < "$requirements" 2> "$log" | tar -C "$dest.tmp" -xf - 2>> "$log" \
   || ! find "$dest.tmp" -name '*.whl' | grep -q .; then
    give_up "could not download the examples' wheels with $image: $(tail -n 3 "$log" | tr '\n' ' ')"
fi
echo "$stamp" > "$dest.tmp/stamp"
rm -rf "$dest" && mv "$dest.tmp" "$dest" && rm -f "$failed" || give_up "could not write $dest"
say "downloaded $(find "$dest" -name '*.whl' | wc -l) wheels for $(grep -m 1 "^Python " "$log") of $image into $dest"
