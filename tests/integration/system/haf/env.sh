#!/bin/bash
if [ -z "${HIVE_BUILD_ROOT_PATH}" ]; then
    export HIVE_BUILD_ROOT_PATH=$(git rev-parse --show-toplevel)/build/hive
fi

if [ -z "${PYTHONPATH}" ]; then
    export PYTHONPATH=$(git rev-parse --show-toplevel)/hive/tests/test_tools/package
fi
export PYTHONPATH=$PYTHONPATH:$(git rev-parse --show-toplevel)/tests/integration/system/local_tools
