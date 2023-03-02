#! /bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
SRC_DIR="$SCRIPT_DIR/../.."

export SRC_DIR_OFFSET="../../.."
"$SRC_DIR/hive/scripts/ci-helpers/build_and_publish_instance.sh" "$@"