#! /bin/bash

set -euo pipefail

# Helper script to check the port used by the specified version of postgres database
# On Ubuntu: uses pg_lsclusters to find the actual port
# On AlmaLinux/RHEL: PostgreSQL always uses default port 5432

POSTGRES_VERSION=$1

if command -v pg_lsclusters &> /dev/null; then
    pg_lsclusters -h | tr -s ' ' | grep ${POSTGRES_VERSION} | cut -d ' ' -f 3
else
    echo "5432"
fi