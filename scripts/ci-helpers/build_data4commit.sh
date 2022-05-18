#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."
SRCROOTDIR="$SCRIPTSDIR/.."

LOG_FILE=build_data4commit.log
source "$SCRIPTSDIR/common.sh"

COMMIT=${1:?"Missing arg 1 to specify COMMIT"}
REGISTRY=${2:?"Missing arg #2 to specify target container registry"}

BUILD_IMAGE_TAG=$COMMIT

BRANCH="master"

do_clone "$BRANCH" "./haf-$COMMIT" https://gitlab.syncad.com/hive/haf.git "$COMMIT"

"$SCRIPTSDIR/ci-helpers/build_data.sh" "$BUILD_IMAGE_TAG" "./haf-${COMMIT}" "$REGISTRY"

