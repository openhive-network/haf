#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."
SRCROOTDIR="$SCRIPTSDIR/.."

LOG_FILE=build_data4commit.log
source "$SCRIPTSDIR/common.sh"

IMGNAME=${1:?"Missing arg #1 to specify IMGNAME"}
shift
COMMIT=${1:?"Missing arg #2 to specify COMMIT"}
shift
REGISTRY=${1:?"Missing arg #3 to specify target container registry"}
shift


BUILD_IMAGE_TAG=$COMMIT

BRANCH="master"

do_clone "$BRANCH" "./haf-$COMMIT" https://gitlab.syncad.com/hive/haf.git "$COMMIT"

"$SCRIPTSDIR/ci-helpers/build_data.sh" "$IMGNAME" "$BUILD_IMAGE_TAG" "./haf-${COMMIT}" "$REGISTRY" "$@"

