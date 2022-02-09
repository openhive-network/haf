#! /bin/bash

set -euo pipefail 

# Helper script to check the port used by specified version of postgres database

POSTGRES_VERSION=$1

pg_lsclusters -h | tr -s ' ' | grep ${POSTGRES_VERSION} | cut -d ' ' -f 3

