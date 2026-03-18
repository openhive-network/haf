#!/bin/bash
# Install pghero monitoring into the haf_block_log database.
# The pghero.sql file is copied into this directory at build time.
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"
psql -U postgres -d haf_block_log -f "$SCRIPT_DIR/pghero.sql"
