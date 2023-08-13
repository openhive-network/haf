#! /bin/bash

set -euo pipefail

LOG_FILE=build.log

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

source "$SCRIPTPATH/../hive/scripts/common.sh"

log_exec_params "$@"

#This script builds all (or selected) targets in the HAF project.

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]... [target]..."
    echo
    echo "Build HAF targets from a HAF source tree."
    echo "  --haf-source-dir=DIRECTORY_PATH"
    echo "                       Specify a directory containing a HAF source tree."
    echo "  --haf-binaries-dir=DIRECTORY_PATH"
    echo "                       Specify a directory to store the build output (HAF binaries)."
    echo "                       Usually it is the \`build\` subdirectory in the HAF source tree."
    echo "  --cmake-arg=ARG      Specify additional arguments to CMake."
    echo "  --help               Display this help screen and exit."
    echo
}

HAF_BINARY_DIR="../build"
HAF_SOURCE_DIR="."
CMAKE_ARGS=()

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
    -*)
        echo "ERROR: '$1' is not a valid option."
        echo
        print_help
        exit 1
        ;;
    *)
        break
        ;;
    esac
    shift
done

abs_src_dir=`realpath -e --relative-base="$SCRIPTPATH" "$HAF_SOURCE_DIR"`
abs_build_dir=`realpath -m --relative-base="$SCRIPTPATH" "$HAF_BINARY_DIR"`

"$SCRIPTPATH/../hive/scripts/build.sh" --source-dir="$abs_src_dir" --binary-dir="$abs_build_dir" "${CMAKE_ARGS[@]}" "$@"



