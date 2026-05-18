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

GIT_SHA="${1:?Usage: $0 <git_sha> <output_dir> [postgres_version]}"
OUTPUT_DIR="${2:?Usage: $0 <git_sha> <output_dir> [postgres_version]}"
POSTGRES_VERSION="${3:-17}"

# Find the hive_fork_manager source directory relative to this script
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"
SRC_DIR="${SCRIPT_DIR}/../src/hive_fork_manager"

if [[ ! -d "$SRC_DIR" ]]; then
    echo "ERROR: Cannot find hive_fork_manager source directory at $SRC_DIR"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Parse SCHEMA_SOURCES / DEPLOY_SOURCES out of the ADD_PSQL_EXTENSION(...) macro
# in CMakeLists.txt. CMakeLists is the single source of truth — see issue #332.
CMAKELISTS="$SRC_DIR/CMakeLists.txt"

parse_cmake_list() {
    awk -v want="$1" '
        { sub(/#.*/, "") }
        /ADD_PSQL_EXTENSION[[:space:]]*\(/ { in_macro = 1 }
        in_macro && /^[[:space:]]*\)/      { in_macro = 0; mode = "" }
        !in_macro { next }
        {
            for (i = 1; i <= NF; i++) {
                tok = $i
                if (tok == "NAME" || tok == "SCHEMA_SOURCES" || tok == "DEPLOY_SOURCES") {
                    mode = tok
                    continue
                }
                if (mode == "NAME") { mode = ""; continue }
                if (mode == want && tok ~ /\.sql$/) print tok
            }
        }
    ' "$CMAKELISTS"
}

mapfile -t SCHEMA_SOURCES < <(parse_cmake_list SCHEMA_SOURCES)
mapfile -t DEPLOY_SOURCES < <(parse_cmake_list DEPLOY_SOURCES)

if [[ ${#SCHEMA_SOURCES[@]} -eq 0 || ${#DEPLOY_SOURCES[@]} -eq 0 ]]; then
    echo "ERROR: failed to parse SCHEMA_SOURCES/DEPLOY_SOURCES from $CMAKELISTS" >&2
    exit 1
fi

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
    # Substitute all template variables
    # POSTGRES_SHAREDIR is where PostgreSQL extensions are installed
    POSTGRES_SHAREDIR="/usr/share/postgresql/${POSTGRES_VERSION}"
    sed -e "s|@HAF_GIT_REVISION_SHA@|${GIT_SHA}|g" \
        -e "s|@POSTGRES_SHAREDIR@|${POSTGRES_SHAREDIR}|g" \
        "$UPDATE_GEN_TEMPLATE" > "$UPDATE_GEN_OUTPUT"
    chmod +x "$UPDATE_GEN_OUTPUT"
fi

echo ""
echo "Extension SQL generated successfully in $OUTPUT_DIR"
echo "Files created:"
ls -la "$OUTPUT_DIR/"
