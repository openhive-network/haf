#! /bin/bash

set -euo pipefail 

LOG_FILE=build.log
exec > >(tee ${LOG_FILE}) 2>&1

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

log_exec_params() {
  echo -n "$0 parameters: "
  for arg in "$@"; do echo -n "$arg"; done
  echo
}

log_exec_params "$@"

#Script purpose is to build all (or selected) targets in the HAF project.

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]... [target]..."
    echo
    echo "Allows to build HAF sources "
    echo "  --haf-source-dir=DIRECTORY_PATH"
    echo "                       Allows to specify a directory containing a HAF source tree."
    echo "  --haf-binaries-dir=DIRECTORY_PATH"
    echo "                       Allows to specify a directory to store a build output (HAF binaries)."
    echo "                       Usually it is a \`build\` subdirectory in the HAF source tree."
    echo "  --cmake-arg=ARG      Allows to specify additional arguments to the CMake tool spawn"
    echo "  --help               Display this help screen and exit"
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
        add_cmake_arg "$arg"
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
        echo "ERROR: '$1' is not a valid option"
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

pwd 
mkdir -vp "$abs_build_dir"
pushd "$abs_build_dir"
pwd
cmake -DCMAKE_BUILD_TYPE=Release "${CMAKE_ARGS[@]}" "$abs_src_dir"
make -j10 "$@"
popd

