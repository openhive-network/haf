#! /bin/bash

set -euo pipefail 

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTPATH/.."
SRCROOTDIR="$SCRIPTSDIR/.."

REGISTRY=registry.gitlab.syncad.com/hive/haf/
IMGNAME="data"

source "$SCRIPTPATH/docker_image_utils.sh"

submodule_path="${1}"

retrieve_submodule_commit () {
  local p="${1}"
  pushd "$p" >/dev/null 2>&1
  local commit=$( git rev-parse HEAD )

  popd >/dev/null 2>&1

  echo "$commit"
}

echo "Attempting to get commit for: $submodule_path"

commit=$( retrieve_submodule_commit ${submodule_path} )

img=$( build_image_name "$IMGNAME" "$commit" "$REGISTRY" )

echo $CI_IMG_BUILDER_PASSWORD | docker login -u $CI_IMG_BUILDER_USER $REGISTRY --password-stdin

if [ "$( docker_image_exists \"$IMGNAME\" \"$commit\" \"$REGISTRY\" )" == 1 ];
then
  echo "${img} image exists. Pulling..."
  docker pull "$img"
else
  # Here continue an image build.
  "$SCRIPTPATH/build_data4commit.sh" "$commit"
  docker push "$img"
fi

echo $img > haf_docked_image.txt