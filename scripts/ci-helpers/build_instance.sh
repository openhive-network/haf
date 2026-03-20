#!/bin/bash
#
# Wrapper around hive's build_instance.sh that also builds the split
# container images (haf-postgres, haf-hived) after the main instance build.
#
# The split targets share all layers with the instance target, so building
# them in the same buildx session is near-instant (~seconds for COPY layers).

set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
HIVE_BUILD_SCRIPT="${SCRIPTPATH}/../../hive/scripts/ci-helpers/build_instance.sh"

# Run the upstream build (builds 'build' and 'instance' targets)
"$HIVE_BUILD_SCRIPT" "$@"

# Parse positional args the same way build_instance.sh does:
#   build_instance.sh <tag> <src_dir> <registry> [--network-type=...] [--export-binaries=...]
BUILD_IMAGE_TAG=""
SOURCE_DIR=""
REGISTRY=""

for arg in "$@"; do
  case "$arg" in
    --*) ;; # skip options
    *)
      if [ -z "$BUILD_IMAGE_TAG" ]; then
        BUILD_IMAGE_TAG="$arg"
      elif [ -z "$SOURCE_DIR" ]; then
        SOURCE_DIR="$arg"
      elif [ -z "$REGISTRY" ]; then
        REGISTRY="$arg"
      fi
      ;;
  esac
done

if [ -z "$BUILD_IMAGE_TAG" ] || [ -z "$SOURCE_DIR" ] || [ -z "$REGISTRY" ]; then
  echo "Note: Could not determine build args for split images, skipping."
  exit 0
fi

# Check if the Dockerfile has split targets
if ! grep -q 'AS haf-postgres' "${SOURCE_DIR}/Dockerfile" 2>/dev/null; then
  exit 0
fi

echo -e "\nBuilding split container images (haf-postgres, haf-hived)...\n"

PG_BUILD_ARG=""
[ -n "${POSTGRES_VERSION:-}" ] && PG_BUILD_ARG="--build-arg POSTGRES_VERSION=${POSTGRES_VERSION}"

BUILD_TIME="${BUILD_TIME:-$(date -u +"%Y-%m-%dT%H:%M:%S")}"
GIT_COMMIT_SHA="${GIT_COMMIT_SHA:-$(git -C "$SOURCE_DIR" rev-parse HEAD 2>/dev/null || echo unknown)}"
GIT_CURRENT_BRANCH="${GIT_CURRENT_BRANCH:-$(git -C "$SOURCE_DIR" branch --show-current 2>/dev/null || echo unknown)}"

# Use the same registry cache keys as the upstream build
CACHE_REPO="${REGISTRY}/cache"
NETWORK="${HIVE_NETWORK_TYPE:-mainnet}"
PG="${POSTGRES_VERSION:-17}"

COMMON_ARGS="--provenance=false --progress=plain"
COMMON_ARGS="$COMMON_ARGS --cache-from=type=registry,ref=${CACHE_REPO}:${NETWORK}-build-pg${PG}"
COMMON_ARGS="$COMMON_ARGS --cache-from=type=registry,ref=${CACHE_REPO}:${NETWORK}-build-pg${PG}-instance"
COMMON_ARGS="$COMMON_ARGS --build-context build=docker-image://${REGISTRY}/build:${BUILD_IMAGE_TAG}"
COMMON_ARGS="$COMMON_ARGS --build-arg BUILD_TIME=$BUILD_TIME"
COMMON_ARGS="$COMMON_ARGS --build-arg GIT_COMMIT_SHA=$GIT_COMMIT_SHA"
COMMON_ARGS="$COMMON_ARGS --build-arg GIT_CURRENT_BRANCH=$GIT_CURRENT_BRANCH"
COMMON_ARGS="$COMMON_ARGS ${PG_BUILD_ARG}"

docker buildx build $COMMON_ARGS \
  --target=haf-postgres \
  --tag "${REGISTRY}/postgres:${BUILD_IMAGE_TAG}" \
  --push \
  --file Dockerfile "$SOURCE_DIR"

docker buildx build $COMMON_ARGS \
  --target=haf-hived \
  --tag "${REGISTRY}/hived:${BUILD_IMAGE_TAG}" \
  --push \
  --file Dockerfile "$SOURCE_DIR"

echo -e "\nSplit images pushed:"
echo "  ${REGISTRY}/postgres:${BUILD_IMAGE_TAG}"
echo "  ${REGISTRY}/hived:${BUILD_IMAGE_TAG}"
