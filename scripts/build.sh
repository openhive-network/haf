#! /bin/bash

set -euo pipefail

export LOG_FILE=build.log

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# shellcheck source=./common.sh
source "$SCRIPTPATH/../hive/scripts/common.sh"

log_exec_params "$@"

#This script builds all (or selected) targets in the HAF project.

print_help () {
cat <<EOF
Usage: $0 [OPTION[=VALUE]]... [target]..."

Build HAF targets from a HAF source tree."
  --haf-source-dir=DIRECTORY_PATH"
                       Specify a directory containing a HAF source tree."
  --haf-binaries-dir=DIRECTORY_PATH"
                       Specify a directory to store the build output (HAF binaries)."
                       Usually it is the \`build\` subdirectory in the HAF source tree."
  --cmake-arg=ARG      Specify additional arguments to CMake."
  --help               Display this help screen and exit."
EOF
}

HAF_BINARY_DIR="../build"
HAF_SOURCE_DIR="."
CMAKE_ARGS=()
ADDITIONAL_ARGS=("--haf-build")

add_cmake_arg () {
  CMAKE_ARGS+=("$1")
}

while [ $# -gt 0 ]; do
  case "$1" in
    --cmake-arg=*)
        arg="${1#*=}"
        add_cmake_arg --cmake-arg="$arg"
        ;;
    --haf-binaries-dir=*)
        HAF_BINARY_DIR="${1#*=}"
        ;;
    --haf-source-dir=*)
        HAF_SOURCE_DIR="${1#*=}"
        ;;
    --help)
        print_help
        exit 0
        ;;
    *)
        ADDITIONAL_ARGS+=("${1}")
        break
        ;;
    esac
    shift
done

abs_src_dir=$(realpath -e --relative-base="$SCRIPTPATH" "$HAF_SOURCE_DIR")
abs_build_dir=$(realpath -m --relative-base="$SCRIPTPATH" "$HAF_BINARY_DIR")

"$SCRIPTPATH/../hive/scripts/build.sh" --source-dir="$abs_src_dir" --binary-dir="$abs_build_dir" "${CMAKE_ARGS[@]}" "${ADDITIONAL_ARGS[@]}"



