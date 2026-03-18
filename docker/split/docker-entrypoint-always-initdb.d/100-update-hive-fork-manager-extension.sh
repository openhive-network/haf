#!/bin/bash
set -euo pipefail

# Update the hive_fork_manager extension on every container startup.
# This handles schema upgrades when the container image is updated.
#
# Runs as the postgres user (PostgreSQL superuser) with trust auth for local
# connections, so no sudo or setuid wrapper is needed.

echo "Checking for hive_fork_manager extension updates..."

# Clean up any leftover temp database from a previously failed upgrade attempt
psql -U haf_admin -d postgres -c "DROP DATABASE IF EXISTS upd_haf_block_log;" 2>/dev/null || true

# Determine the PostgreSQL version for extension file paths
PG_VERSION=$(pg_config --version | sed 's/[^0-9]*\([0-9]*\).*/\1/')
UPDATE_SCRIPT="/usr/share/postgresql/${PG_VERSION}/extension/hive_fork_manager_update_script_generator.sh"

if [ -f "$UPDATE_SCRIPT" ]; then
  "$UPDATE_SCRIPT" --haf-admin-account=haf_admin --haf-db-name=haf_block_log
else
  echo "WARNING: Extension update script not found at $UPDATE_SCRIPT"
fi

echo "Extension update check complete."
