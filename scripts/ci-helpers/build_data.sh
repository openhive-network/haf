#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."
SRCROOTDIR="$SCRIPTSDIR/.."

LOG_FILE=build_data.log
source "$SCRIPTSDIR/common.sh"

BUILD_IMAGE_TAG=${1?"Missing arg 1 to specify BUILD_IMAGE_TAG"}

REGISTRY=${2:-registry.gitlab.syncad.com/hive/haf/}

CI_IMAGE_TAG=${3:-:ubuntu20.04-5}

BLOCK_LOG_SUFFIX="-5m"

"$SCRIPTSDIR/ci-helpers/build_instance.sh" "${BUILD_IMAGE_TAG}" "${REGISTRY}" "${BLOCK_LOG_SUFFIX}"

pushd "$SRCROOTDIR"

docker build --target=data \
  --build-arg CI_REGISTRY_IMAGE=$REGISTRY --build-arg CI_IMAGE_TAG=$CI_IMAGE_TAG --build-arg BLOCK_LOG_SUFFIX="-5m" \
  --build-arg BUILD_IMAGE_TAG=:$BUILD_IMAGE_TAG -t ${REGISTRY}data:$BUILD_IMAGE_TAG -f Dockerfile .

popd
