#!/bin/bash

set -e

docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"

scripts/ci-helpers/build_instance.sh "$CI_COMMIT_SHA" "$CI_PROJECT_DIR" "$CI_REGISTRY_IMAGE/" --network-type=mainnet

docker push "${CI_REGISTRY_IMAGE}/base_instance:base_instance-${CI_COMMIT_SHA}"