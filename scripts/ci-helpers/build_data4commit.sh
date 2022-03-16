#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."
SRCROOTDIR="$SCRIPTSDIR/.."

LOG_FILE=build_data4commit.log
source "$SCRIPTSDIR/common.sh"

COMMIT="$1"

BUILD_IMAGE_TAG=:$COMMIT

REGISTRY=${2:-registry.gitlab.syncad.com/hive/haf}

CI_IMAGE_TAG=:ubuntu20.04-4

pushd "$SRCROOTDIR"
pwd

echo $BUILD_IMAGE_TAG

docker build --target=base_instance \
  --build-arg CI_REGISTRY_IMAGE=$REGISTRY --build-arg CI_IMAGE_TAG=$CI_IMAGE_TAG --build-arg BLOCK_LOG_SUFFIX="-5m" \
  --build-arg COMMIT=$COMMIT --build-arg BUILD_IMAGE_TAG=$BUILD_IMAGE_TAG -t $REGISTRY/base_instance-5m$BUILD_IMAGE_TAG -f Dockerfile .

docker build --target=base_instance \
  --build-arg CI_REGISTRY_IMAGE=$REGISTRY --build-arg CI_IMAGE_TAG=$CI_IMAGE_TAG --build-arg BLOCK_LOG_SUFFIX="-5m" \
  --build-arg COMMIT=$COMMIT --build-arg BUILD_IMAGE_TAG=$BUILD_IMAGE_TAG -t $REGISTRY/instance-5m$BUILD_IMAGE_TAG -f Dockerfile .


docker build --target=data \
  --build-arg CI_REGISTRY_IMAGE=$REGISTRY --build-arg CI_IMAGE_TAG=$CI_IMAGE_TAG --build-arg BLOCK_LOG_SUFFIX="-5m" \
  --build-arg COMMIT=$COMMIT --build-arg BUILD_IMAGE_TAG=$BUILD_IMAGE_TAG -t $REGISTRY/data$BUILD_IMAGE_TAG -f Dockerfile .

popd
