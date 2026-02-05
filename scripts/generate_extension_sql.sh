#!/bin/bash
# Generate PostgreSQL extension SQL files without CMake/compilation
# This script recreates the extension SQL by concatenating source files
# exactly as cmake/sql_extension.cmake does.
#
# Usage: generate_extension_sql.sh <git_sha> <output_dir>
#
# This enables thin Docker overlay builds when only SQL files change,
# avoiding the need for full C++ recompilation.

set -euo pipefail

GIT_SHA="${1:?Usage: $0 <git_sha> <output_dir>}"
OUTPUT_DIR="${2:?Usage: $0 <git_sha> <output_dir>}"

# Find the hive_fork_manager source directory relative to this script
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"
SRC_DIR="${SCRIPT_DIR}/../src/hive_fork_manager"

if [[ ! -d "$SRC_DIR" ]]; then
    echo "ERROR: Cannot find hive_fork_manager source directory at $SRC_DIR"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Schema sources - defines table structures and base types
# These must be loaded first (from CMakeLists.txt SCHEMA_SOURCES)
SCHEMA_SOURCES=(
    schemas.sql
    context_rewind/data_schema_types.sql
    application_loop/stages.sql
    context_rewind/data_schema.sql
    events_queue.sql
    forks.sql
    app_context.sql
    types/domains.sql
    types/operation/operation.sql
    types/operation/operation_flow.sql
    types/operation/operation_impl.sql
    types/operation/operation_cmp.sql
    types/operation/operation_casts.sql
    types/operation/operation_id.sql
    types/asset_unique_id.sql
    irreversible_blocks.sql
    reversible_blocks.sql
    state_provider.sql
    hived_connections.sql
    hived_api_impl_indexes.sql
    hived_api.sql
    state_providers/keyauth_types.sql
    save_restore_view_data.sql
    application_loop/contexts_log.sql
)

# Deploy sources - functions and procedures that can be updated
# These are loaded after schema sources (from CMakeLists.txt DEPLOY_SOURCES)
DEPLOY_SOURCES=(
    custom_json_type_schema_update.sql
    trigger_switch/trigger_off.sql
    context_rewind/sink_id_functions.sql
    context_rewind/names.sql
    context_rewind/triggers.sql
    context_rewind/event_triggers.sql
    context_rewind/register_table.sql
    context_rewind/detach_table.sql
    context_rewind/back_from_fork.sql
    context_rewind/irreversible.sql
    context_rewind/rewind_api.sql
    types/operation/compatibility_with_old_haf_apps.sql
    types/operation/operation_flow.sql
    types/operation/operation_id.sql
    types/asset_unique_id.sql
    pruning/prune_irreversible_blocks.sql
    tools.sql
    block_views_for_head_block.sql
    block_day_stats_view.sql
    block_day_stats_all_op_view.sql
    blocks_views_for_contexts.sql
    state_providers/keyauth.sql
    get_keyauths.sql
    get_required_authorities.sql
    get_metadata.sql
    get_vesting_balance.sql
    state_providers/accounts.sql
    state_providers/metadata.sql
    hived_api_impl.sql
    app_api_impl.sql
    hived_api.sql
    app_api.sql
    api_helpers/block_api_support.sql
    authorization.sql
    get_impacted_accounts.sql
    get_impacted_balances.sql
    rc_delegation.sql
    convert_blocks.sql
    get_legacy_style_operation.sql
    extract_set_witness_properties.sql
    trigger_switch/trigger_on.sql
    types/types.sql
    types/cast_functions.sql
    types/casts.sql
    types/operation/operation_flow.sql
    types/process_operation.sql
    asset_utils.sql
    transaction_utils.sql
    application_loop/stages_functions.sql
    application_loop/loop.sql
    application_loop/contexts_log_api.sql
    state_providers/update_providers.sql
    vacuum_shadow_table.sql
)

# Verify all source files exist before starting
echo "Verifying source files..."
for f in "${SCHEMA_SOURCES[@]}"; do
    if [[ ! -f "$SRC_DIR/$f" ]]; then
        echo "ERROR: Missing schema source file: $SRC_DIR/$f"
        exit 1
    fi
done
for f in "${DEPLOY_SOURCES[@]}"; do
    if [[ ! -f "$SRC_DIR/$f" ]]; then
        echo "ERROR: Missing deploy source file: $SRC_DIR/$f"
        exit 1
    fi
done

# Generate main extension script (SCHEMA_SOURCES + DEPLOY_SOURCES)
# This is used for fresh installs: CREATE EXTENSION hive_fork_manager
MAIN_SCRIPT="$OUTPUT_DIR/hive_fork_manager--${GIT_SHA}.sql"
echo "Generating $MAIN_SCRIPT..."
: > "$MAIN_SCRIPT"  # Truncate/create empty file
for f in "${SCHEMA_SOURCES[@]}"; do
    cat "$SRC_DIR/$f" >> "$MAIN_SCRIPT"
done
for f in "${DEPLOY_SOURCES[@]}"; do
    cat "$SRC_DIR/$f" >> "$MAIN_SCRIPT"
done

# Generate update script (header + DEPLOY_SOURCES)
# This is used for upgrades: ALTER EXTENSION hive_fork_manager UPDATE
UPDATE_SCRIPT="$OUTPUT_DIR/hive_fork_manager_update--${GIT_SHA}.sql"
echo "Generating $UPDATE_SCRIPT..."
# Write the update header (matches cmake/sql_extension.cmake .update_header.sql)
cat > "$UPDATE_SCRIPT" << 'HEADER'
DO $$ BEGIN RAISE WARNING 'Extension is being updated'; END $$;
DROP SCHEMA IF EXISTS hive CASCADE;
CREATE SCHEMA hive;
HEADER
# Append all deploy sources
for f in "${DEPLOY_SOURCES[@]}"; do
    cat "$SRC_DIR/$f" >> "$UPDATE_SCRIPT"
done

# Generate control file
CONTROL_FILE="$OUTPUT_DIR/hive_fork_manager.control"
echo "Generating $CONTROL_FILE..."
cat > "$CONTROL_FILE" << EOF
# hive_fork_manager psql extension
comment = 'An extension to support hive forks'
default_version = '${GIT_SHA}'
module_pathname = '\$libdir/libhfm-${GIT_SHA}.so'
relocatable = false
schema = hafd
# this extension is required by block_day_stats views performing a PIVOT operation
requires = 'tablefunc'
EOF

# Copy static files
echo "Copying static files..."
cp "$SRC_DIR/update.sql" "$OUTPUT_DIR/"

# Generate update script generator from template
UPDATE_GEN_TEMPLATE="$SRC_DIR/hive_fork_manager_update_script_generator.sh.in"
UPDATE_GEN_OUTPUT="$OUTPUT_DIR/hive_fork_manager_update_script_generator.sh"
if [[ -f "$UPDATE_GEN_TEMPLATE" ]]; then
    sed "s/@HAF_GIT_REVISION_SHA@/${GIT_SHA}/g" "$UPDATE_GEN_TEMPLATE" > "$UPDATE_GEN_OUTPUT"
    chmod +x "$UPDATE_GEN_OUTPUT"
fi

echo ""
echo "Extension SQL generated successfully in $OUTPUT_DIR"
echo "Files created:"
ls -la "$OUTPUT_DIR/"
