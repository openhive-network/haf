#!/bin/sh
#
# source-patterns.sh - Patterns for files that trigger HAF image rebuilds
#
# These are SOURCE CODE patterns only - changes to these files require
# rebuilding HAF binaries. Used by:
#   - find-upstream-image.sh (find last source commit for image lookup)
#   - downstream repos like HAfAH (find HAF images via URL fetch)
#
# NOT included here (handled separately in .gitlab-ci.yml detect_changes):
#   - Test patterns (tests/) - trigger test runs, not rebuilds
#   - Doc patterns (docs/, *.md) - skip CI entirely
#   - SQL patterns (*.sql) - trigger replay, not rebuild
#
# Usage:
#   source-patterns.sh           # comma-separated (for git log pathspecs)
#   source-patterns.sh --regex   # regex pattern (for grep -E)

PATTERNS="src/
hive/
cmake/
CMakeLists.txt
Dockerfile
docker/
scripts/
common_includes/
.gitmodules"

case "${1:-}" in
    --regex)
        # Output as regex for grep -E: ^(src/|hive/|...)
        printf '^(%s)' "$(echo "$PATTERNS" | tr '\n' '|' | sed 's/|$//')"
        ;;
    *)
        # Output as comma-separated for git pathspecs
        echo "$PATTERNS" | tr '\n' ',' | sed 's/,$//'
        ;;
esac
