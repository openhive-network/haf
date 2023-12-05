#! /bin/bash

P="${1}"
pushd "$P" >/dev/null 2>&1 || exit 1
# this list is used to detect changes affecting hived binaries, list might change in the future
COMMIT=$(git log --pretty=format:"%H" -- hive/ src/ cmake/ scripts/ docker/ tests/unit tests/integration/functional Dockerfile CMakeLists.txt | head -1)

popd >/dev/null 2>&1 || exit 1

echo "$COMMIT"
