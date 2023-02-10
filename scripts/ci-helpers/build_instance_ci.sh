#!/bin/bash

set -e

docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"

HAF_IMAGE_NAME="${CI_REGISTRY_IMAGE}/base_instance:base_instance-${CI_COMMIT_SHA}"
echo "Pulling image $HAF_IMAGE_NAME"
docker pull "$HAF_IMAGE_NAME"

pushd "$CI_PROJECT_DIR"

# Build the instance image
TAG="${CI_REGISTRY_IMAGE}/instance:instance-${CI_COMMIT_SHA}"
echo "Building image $TAG"
docker buildx build --progress=plain --target=instance \
  --build-arg CI_REGISTRY_IMAGE="$CI_REGISTRY_IMAGE/" \
  --build-arg BUILD_HIVE_TESTNET="OFF" \
  --build-arg HIVE_CONVERTER_BUILD="OFF" \
  --build-arg BUILD_IMAGE_TAG="$CI_COMMIT_SHA" \
  --cache-from=type=registry,ref="$TAG" \
  --cache-to=type=inline \
  --tag "$TAG" \
  --file "Dockerfile" .

docker push "$TAG"  

popd