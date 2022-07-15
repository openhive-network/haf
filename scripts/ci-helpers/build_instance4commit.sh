#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."

LOG_FILE=build_instance4commit.log
source "$SCRIPTSDIR/common.sh"

COMMIT=${1:?"Missing arg 1 to specify COMMIT"}
shift
BRANCH="master"


BUILD_IMAGE_TAG=$COMMIT

do_clone "$BRANCH" "./haf-${COMMIT}" https://gitlab.syncad.com/hive/haf.git "$COMMIT"

"$SCRIPTSDIR/ci-helpers/build_instance.sh" "${BUILD_IMAGE_TAG}" "./haf-${COMMIT}" $@
