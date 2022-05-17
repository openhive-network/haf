#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."
SRCROOTDIR="$SCRIPTSDIR/.."

LOG_FILE=build_instance.log
source "$SCRIPTSDIR/common.sh"

BUILD_IMAGE_TAG=:${1?"Missing arg 1 to specify BUILD_IMAGE_TAG"}

REGISTRY=${2:-registry.gitlab.syncad.com/hive/haf/}

BLOCK_LOG_SUFFIX=${3:-}

CI_IMAGE_TAG=${4:-:ubuntu20.04-5}

echo "Moving into source root directory: $SRCROOTDIR"

pushd "$SRCROOTDIR"
pwd

docker build --target=base_instance \
  --build-arg BLOCK_LOG_SUFFIX="${BLOCK_LOG_SUFFIX}" \
  --build-arg CI_REGISTRY_IMAGE=$REGISTRY --build-arg CI_IMAGE_TAG=$CI_IMAGE_TAG \
  --build-arg BUILD_IMAGE_TAG=$BUILD_IMAGE_TAG -t ${REGISTRY}base_instance${BLOCK_LOG_SUFFIX}${BUILD_IMAGE_TAG} -f Dockerfile .

# Build the image containing only binaries and be ready to start running HAF instance, operating on mounted volummes pointing instance datadir and shm_dir
docker build --target=instance \
  --build-arg BLOCK_LOG_SUFFIX="${BLOCK_LOG_SUFFIX}" \
  --build-arg CI_REGISTRY_IMAGE=$REGISTRY --build-arg CI_IMAGE_TAG=$CI_IMAGE_TAG \
  --build-arg BUILD_IMAGE_TAG=$BUILD_IMAGE_TAG -t ${REGISTRY}instance${BLOCK_LOG_SUFFIX}${BUILD_IMAGE_TAG} -f Dockerfile .

popd


