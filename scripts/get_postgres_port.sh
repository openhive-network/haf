#! /bin/bash

set -euo pipefail

# Helper script to check the port used by the specified version of postgres database

POSTGRES_VERSION=$1

if command -v pg_lsclusters >/dev/null 2>&1; then
    pg_lsclusters -h | tr -s ' ' | grep ${POSTGRES_VERSION} | cut -d ' ' -f 3
else
    # macOS / non-Debian: fall back to pg_config-derived default or 5432
    pg_config --configure 2>/dev/null | tr ' ' '\n' | sed -n "s/^--with-pgport=//p" | head -1 | grep -E '^[0-9]+$' || echo 5432
fi

