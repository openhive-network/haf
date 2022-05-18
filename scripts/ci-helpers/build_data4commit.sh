#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."
SRCROOTDIR="$SCRIPTSDIR/.."

LOG_FILE=build_data4commit.log
source "$SCRIPTSDIR/common.sh"

COMMIT="$1"

BUILD_IMAGE_TAG=$COMMIT

REGISTRY=${2:-registry.gitlab.syncad.com/hive/haf/}

BRANCH=${3:-master}

CI_IMAGE_TAG=${4:-:ubuntu20.04-5}

do_clone "$BRANCH" ./haf https://gitlab.syncad.com/hive/haf.git "$COMMIT"

"$SCRIPTSDIR/ci-helpers/build_data.sh" "$BUILD_IMAGE_TAG" "$REGISTRY"

