#!/bin/bash

set -e


CI_REGISTRY_IMAGE=${CI_REGISTRY_IMAGE:-"registry.gitlab.syncad.com/hive/haf"}
HAF_REGISTRY_PATH=${HAF_REGISTRY_PATH:-"${CI_REGISTRY_IMAGE}/base_instance"}
HAF_REGISTRY_TAG=${HAF_REGISTRY_TAG:-"latest"}
BUILD_DIR=${BUILD_DIR:-$(pwd)}
FAKETIME=${FAKETIME:-"@2016-09-16 01:21:33"}

print_help () {
cat <<-EOF
  Usage: $0 [OPTION[=VALUE]]...

  Builds Docker image containing HAF installation with faketime enabled.
  The image will be tagged as "\${HRPATH/base_/faketime-}:\${FTAG}".
  Using default values this resolves to "registry.gitlab.syncad.com/hive/haf/faketime-instance:latest".
  OPTIONS:
    --source-dir=DIR            Source directory (default: $(pwd))
    --registry=REGISTRY         Docker registry to use (default: registry.gitlab.syncad.com/hive/haf),
    --faketime-tag=FTAG         Tag for the new image (default: the same as the base image's tag)
    --haf-registry-path=HRPATH  Base Docker imag registry path (default: \$REGISTRY/base_instance)
    --haf-registry-tag=HRTAG    Tag of the base image to use (default: latest)
    --faketime=TIME             Time to be set in the image (default: @2016-09-16 01:21:33), can be overridden at runtime                 
    --help,-h,-?                Displays this help screen and exits
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --source-dir=*)
        BUILD_DIR="${1#*=}"
        ;;
    --registry=*)
        CI_REGISTRY_IMAGE="${1#*=}"
        ;;
    --faketime-tag=*)
        FAKETIME_TAG="${1#*=}"
        ;;
    --haf-registry-path=*)
        HAF_REGISTRY_PATH="${1#*=}"
        ;;
    --haf-registry-tag=*)
        HAF_REGISTRY_TAG="${1#*=}"
        ;;
    --faketime=*)
        FAKETIME="${1#*=}"
        ;;
    --help|-h|-\?)
        print_help
        exit 0
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option."
        exit 1
        ;;
    *)
        if [ -z "$COMMIT" ];
        then
          COMMIT="$1"
        elif [ -z "$REGISTRY" ];
        then
          REGISTRY=$1
        else
          echo "ERROR: '$1' is not a valid positional argument."
          echo
          print_help
          exit 2
        fi
        ;;
    esac
    shift
done

FAKETIME_TAG=${FAKETIME_TAG:-${HAF_REGISTRY_TAG}}
HAF_FAKETIME_INSTANCE="${HAF_REGISTRY_PATH/base_/faketime-}:${FAKETIME_TAG}"
HAF_BASE_REGISTRY="${HAF_REGISTRY_PATH##*/}"
HAF_PREFIX="${HAF_BASE_REGISTRY%base_instance}"

cat <<EOF
HAF registry path: $HAF_REGISTRY_PATH
HAF registry tag: $HAF_REGISTRY_TAG
Faketime image tag: $FAKETIME_TAG
Registry: $CI_REGISTRY_IMAGE
Faketime image full tag: $HAF_FAKETIME_INSTANCE
Source directory: $BUILD_DIR
HAF base registry suffix: $HAF_BASE_REGISTRY
HAF prefix: $HAF_PREFIX
Fake time: $FAKETIME
EOF

pushd "${BUILD_DIR}" || exit 1

BUILD_OPTIONS=("--platform=linux/amd64" "--target=faketime-instance" "--progress=plain")
# On CI push the image to the registry
if [[ -n "${CI:-}" ]]; then
  BUILD_OPTIONS+=("--push")
else
  BUILD_OPTIONS+=("--load")
fi

docker buildx build "${BUILD_OPTIONS[@]}" \
    --build-arg CI_REGISTRY_IMAGE="${CI_REGISTRY_IMAGE}/" \
    --build-arg BUILD_IMAGE_TAG="${HAF_REGISTRY_TAG}" \
    --build-arg FAKETIME="${FAKETIME}" \
    --build-arg IMAGE_TAG_PREFIX="${HAF_PREFIX}" \
    --tag "${HAF_FAKETIME_INSTANCE}" \
    --file Dockerfile "${BUILD_DIR}"

popd || exit 1

echo "HAF_FAKETIME_INSTANCE=${HAF_FAKETIME_INSTANCE}" >> docker_image_name.env
cat docker_image_name.env