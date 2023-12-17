#! /bin/bash

REGISTRY=${1:-registry.gitlab.syncad.com/hive/haf/}
CI_IMAGE_TAG=ubuntu22.04-7

# exit when any command fails
set -e

docker buildx build --progress=plain --target=ci-base-image \
  --build-arg CI_REGISTRY_IMAGE="$REGISTRY" --build-arg CI_IMAGE_TAG=$CI_IMAGE_TAG \
  --build-arg BUILD_IMAGE_TAG=$CI_IMAGE_TAG \
  -t "${REGISTRY}ci-base-image:$CI_IMAGE_TAG" -f Dockerfile .
