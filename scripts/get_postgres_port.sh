#! /bin/bash

set -euo pipefail 

# Helper script to check the port used by specified version of postgres database

POSTGRES_VERSION=$1

pg_lsclusters -h | grep -E --regexp="^${POSTGRES_VERSION}\s\w+\s(([[:digit:]])+)" | cut -d ' ' -f 3

