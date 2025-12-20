#!/bin/bash
#
# list-haf-caches.sh - List available HAF cache keys for quick-test mode
#
# This script shows cached HAF replay data that can be used with QUICK_TEST mode.
# Each cache key corresponds to a HAF commit SHA that has pre-replayed 5M block data.
#
# Usage:
#   ./scripts/ci-helpers/list-haf-caches.sh           # List all HAF caches
#   ./scripts/ci-helpers/list-haf-caches.sh --recent  # Show only recent (last 10)
#   ./scripts/ci-helpers/list-haf-caches.sh --check <sha>  # Check if specific SHA is cached
#
# The output can be used to set QUICK_TEST_HAF_COMMIT in CI pipelines.
#

set -euo pipefail

CACHE_NFS_PATH="${CACHE_NFS_PATH:-/nfs/ci-cache}"
HAF_CACHE_PATH="${CACHE_NFS_PATH}/haf"

usage() {
    cat << 'EOF'
Usage: list-haf-caches.sh [OPTIONS]

List available HAF cache keys for quick-test mode.

Options:
  --recent       Show only the 10 most recent caches
  --check SHA    Check if a specific commit SHA is cached
  --size         Include cache sizes (slower)
  --json         Output as JSON
  -h, --help     Show this help

Examples:
  # List all available caches
  ./scripts/ci-helpers/list-haf-caches.sh

  # Check if a specific commit has cached data
  ./scripts/ci-helpers/list-haf-caches.sh --check 9ce4243d23

  # Show recent caches with sizes
  ./scripts/ci-helpers/list-haf-caches.sh --recent --size

Quick Test Usage:
  Once you find a cache key, use it in CI:
    QUICK_TEST=true
    QUICK_TEST_HAF_COMMIT=<sha-from-this-list>
EOF
    exit 0
}

# Check if we can access NFS
check_nfs_access() {
    if [[ ! -d "$HAF_CACHE_PATH" ]]; then
        echo "ERROR: Cannot access HAF cache at $HAF_CACHE_PATH" >&2
        echo "" >&2
        echo "If running locally, access via jump host:" >&2
        echo "  ssh -A steem-18 \"ssh hive-builder-10 'ls $HAF_CACHE_PATH'\"" >&2
        exit 1
    fi
}

# List caches as tar files (new format)
list_tar_caches() {
    local show_size="${1:-false}"
    local limit="${2:-0}"

    local count=0
    # Sort by modification time (newest first)
    for tar_file in $(ls -t "$HAF_CACHE_PATH"/*.tar 2>/dev/null); do
        [[ -f "$tar_file" ]] || continue

        local basename=$(basename "$tar_file" .tar)
        local mtime=$(stat -c %Y "$tar_file" 2>/dev/null || echo 0)
        local date=$(date -d "@$mtime" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")

        if [[ "$show_size" == "true" ]]; then
            local size=$(du -h "$tar_file" 2>/dev/null | cut -f1 || echo "?")
            printf "%-45s %s  %s\n" "$basename" "$date" "$size"
        else
            printf "%-45s %s\n" "$basename" "$date"
        fi

        count=$((count + 1))
        if [[ $limit -gt 0 && $count -ge $limit ]]; then
            break
        fi
    done

    return $count
}

# List caches as directories (legacy format)
list_dir_caches() {
    local show_size="${1:-false}"
    local limit="${2:-0}"

    local count=0
    for dir in $(ls -td "$HAF_CACHE_PATH"/*/ 2>/dev/null); do
        [[ -d "$dir" ]] || continue
        # Skip if there's also a tar file (prefer tar)
        local basename=$(basename "$dir")
        [[ -f "$HAF_CACHE_PATH/${basename}.tar" ]] && continue

        local mtime=$(stat -c %Y "$dir" 2>/dev/null || echo 0)
        local date=$(date -d "@$mtime" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")

        if [[ "$show_size" == "true" ]]; then
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "?")
            printf "%-45s %s  %s (dir)\n" "$basename" "$date" "$size"
        else
            printf "%-45s %s (dir)\n" "$basename" "$date"
        fi

        count=$((count + 1))
        if [[ $limit -gt 0 && $count -ge $limit ]]; then
            break
        fi
    done

    return $count
}

# Check if a specific SHA is cached
check_cache() {
    local sha="$1"

    # Check for tar file
    if [[ -f "$HAF_CACHE_PATH/${sha}.tar" ]]; then
        echo "FOUND: $HAF_CACHE_PATH/${sha}.tar"
        ls -lh "$HAF_CACHE_PATH/${sha}.tar"
        return 0
    fi

    # Check for directory
    if [[ -d "$HAF_CACHE_PATH/${sha}" ]]; then
        echo "FOUND: $HAF_CACHE_PATH/${sha}/ (directory format)"
        du -sh "$HAF_CACHE_PATH/${sha}"
        return 0
    fi

    # Check for partial match
    local matches=$(ls "$HAF_CACHE_PATH" 2>/dev/null | grep "^${sha}" | head -5)
    if [[ -n "$matches" ]]; then
        echo "No exact match for '$sha', but found partial matches:"
        echo "$matches"
        return 1
    fi

    echo "NOT FOUND: No cache for SHA '$sha'"
    echo ""
    echo "Use --recent to see available caches"
    return 1
}

# Output as JSON
output_json() {
    local limit="${1:-0}"

    echo "["
    local first=true
    local count=0

    for tar_file in $(ls -t "$HAF_CACHE_PATH"/*.tar 2>/dev/null); do
        [[ -f "$tar_file" ]] || continue

        local basename=$(basename "$tar_file" .tar)
        local mtime=$(stat -c %Y "$tar_file" 2>/dev/null || echo 0)
        local size=$(stat -c %s "$tar_file" 2>/dev/null || echo 0)

        [[ "$first" != "true" ]] && echo ","
        first=false

        cat << EOF
  {
    "sha": "$basename",
    "timestamp": $mtime,
    "size_bytes": $size,
    "path": "$tar_file"
  }
EOF
        count=$((count + 1))
        if [[ $limit -gt 0 && $count -ge $limit ]]; then
            break
        fi
    done

    echo ""
    echo "]"
}

# Main
main() {
    local show_recent=false
    local show_size=false
    local output_format="text"
    local check_sha=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --recent)
                show_recent=true
                shift
                ;;
            --size)
                show_size=true
                shift
                ;;
            --json)
                output_format="json"
                shift
                ;;
            --check)
                check_sha="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                ;;
        esac
    done

    check_nfs_access

    # Handle --check
    if [[ -n "$check_sha" ]]; then
        check_cache "$check_sha"
        exit $?
    fi

    # Handle --json
    if [[ "$output_format" == "json" ]]; then
        if [[ "$show_recent" == "true" ]]; then
            output_json 10
        else
            output_json 0
        fi
        exit 0
    fi

    # Text output
    echo "Available HAF Caches (for QUICK_TEST_HAF_COMMIT)"
    echo "================================================"
    echo ""

    if [[ "$show_size" == "true" ]]; then
        printf "%-45s %-17s %s\n" "COMMIT SHA" "DATE" "SIZE"
        printf "%-45s %-17s %s\n" "----------" "----" "----"
    else
        printf "%-45s %s\n" "COMMIT SHA" "DATE"
        printf "%-45s %s\n" "----------" "----"
    fi

    local limit=0
    [[ "$show_recent" == "true" ]] && limit=10

    list_tar_caches "$show_size" "$limit"
    local tar_count=$?

    list_dir_caches "$show_size" "$limit"
    local dir_count=$?

    local total=$((tar_count + dir_count))

    echo ""
    echo "Total: $total caches"

    if [[ "$show_recent" == "true" && $total -ge 10 ]]; then
        echo "(showing 10 most recent, use without --recent for all)"
    fi

    echo ""
    echo "Usage: Set QUICK_TEST_HAF_COMMIT=<sha> in CI pipeline variables"
}

main "$@"
