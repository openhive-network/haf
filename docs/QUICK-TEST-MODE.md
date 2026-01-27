# HAF Quick Test / Auto-Skip Mode

This feature allows HAF CI pipelines to skip builds and replays when they're not needed, dramatically reducing pipeline time from ~60 minutes to ~5 minutes.

## Two Modes

### 1. Automatic Mode (Recommended)

The pipeline automatically detects what changed and optimizes accordingly:

#### A. Tests/Docs Only → Skip Build AND Replay (~5 min)
When you push changes that **only affect tests or documentation**:
- Skips `haf_image_build` (uses cached HAF image)
- Skips replay (uses cached 5M block data from NFS)
- Runs tests immediately

**Files that trigger full skip:**
- `tests/**/*` - Test code
- `docs/**/*` - Documentation
- `*.md`, `README*`, `CHANGELOG*`, `LICENSE*` - Markdown/text files

#### B. SQL Changes → Skip Build, Do Replay (~35 min)
When you push **SQL changes** (but no C++ changes):
- Skips `haf_image_build` (uses cached HAF image)
- Performs fresh replay (SQL affects block processing)
- Runs tests with new SQL applied

**Files that skip build but require replay:**
- `*.sql` - SQL schema/function changes

#### C. Core Changes → Full Build + Replay (~60 min)
When you push **C++ or build system changes**:
- Full `haf_image_build` (recompiles everything)
- Fresh replay with new binaries
- Runs all tests

**Files that require full build:**
- `src/**/*` - C++ source code
- `CMakeLists.txt`, `*.cmake` - Build configuration
- `docker/**/*` - Docker configuration
- `hive/` submodule changes

### 2. Manual Mode (QUICK_TEST)

For explicit control, set CI variables to force quick mode with a specific cache:

| Variable | Required | Description |
|----------|----------|-------------|
| `QUICK_TEST` | Yes | Set to `true` to enable |
| `QUICK_TEST_HAF_COMMIT` | Yes | HAF commit SHA with cached data |
| `QUICK_TEST_HAF_IMAGE` | No | HAF image to use (default: `:develop`) |
| `QUICK_TEST_JOBS` | No | Additional jobs to run (comma-separated) |

**Example:**
```
QUICK_TEST=true
QUICK_TEST_HAF_COMMIT=9ce4243d23b6f27ab9023a401ada586a856b8848
```

## How It Works

```
Full Build (C++ changes):     SQL Only:                   Tests/Docs Only:
┌─────────────────────┐      ┌─────────────────────┐     ┌─────────────────────┐
│ detect_changes      │      │ detect_changes      │     │ detect_changes      │
├─────────────────────┤      ├─────────────────────┤     ├─────────────────────┤
│ haf_image_build     │15min │ quick_test_setup    │10s  │ quick_test_setup    │10s
├─────────────────────┤      │ (use cached image)  │     │ (use cached image)  │
│ prepare_haf_data    │30min ├─────────────────────┤     ├─────────────────────┤
│ (replay 5M blocks)  │      │ prepare_haf_data    │30min│ prepare_haf_data    │30s
├─────────────────────┤      │ (fresh replay)      │     │ (fetch from cache)  │
│ test_job            │5min  ├─────────────────────┤     ├─────────────────────┤
└─────────────────────┘      │ test_job            │5min │ test_job            │5min
Total: ~50 min               └─────────────────────┘     └─────────────────────┘
                             Total: ~35 min              Total: ~5 min
```

1. **detect_changes**: Analyzes which files changed to determine if build can be skipped
2. **quick_test_setup**: Finds cached data and exports `HAF_COMMIT` and `HAF_IMAGE_NAME`
3. **prepare_haf_data**: Fetches cached replay data from NFS instead of replaying
4. **Tests**: Run using the cached data

## Smart Image Re-tagging

When only test/doc changes are made over multiple commits, the cached image may become "stale" - meaning downstream repos searching for the image by commit history won't find it because too many commits have been pushed.

The build system uses smart re-tagging to prevent this:

```
                Gap = commits between cached image and current HEAD
                (only counting source-changing commits)

┌─────────────────────┬─────────────────────┬─────────────────────┐
│ Gap <= 20           │ 20 < Gap <= 25      │ Gap > 25            │
│ (Small)             │ (Medium)            │ (Large)             │
├─────────────────────┼─────────────────────┼─────────────────────┤
│ Use cached image    │ Re-tag cached       │ Force full rebuild  │
│ as-is               │ image to current    │ (fail-safe)         │
│                     │ commit SHA          │                     │
│                     │                     │                     │
│ Downstream search   │ Keeps image         │ Ensures image       │
│ will find it        │ findable within     │ always exists       │
│                     │ search depth        │                     │
└─────────────────────┴─────────────────────┴─────────────────────┘
```

**Configuration variables:**
- `RETAG_THRESHOLD=20` - Re-tag when gap exceeds this
- `SEARCH_DEPTH=25` - Force rebuild when gap exceeds this

**Why this matters:**
- Downstream repos (like HAfAH, hivemind) search HAF's git history to find images
- Default search depth is 25 commits (counting only source-changing commits)
- If many test-only commits are pushed, the cached image may fall outside this window
- Smart re-tagging ensures images are always findable without unnecessary rebuilds

## Finding Available Cache Keys

### Option 1: Use the helper script
```bash
./scripts/ci-helpers/list-haf-caches.sh --recent
```

### Option 2: SSH to builder
```bash
ssh -A steem-18 "ssh hive-builder-10 'ls -lt /nfs/ci-cache/haf/*.tar | head -10'"
```

## When Quick Mode Won't Work

The pipeline will fall back to full build/replay when:

1. **No cached data available** - NFS cache is empty or inaccessible
2. **Core code changed** - Any file outside tests/docs was modified
3. **Tagged builds** - Release builds always run full pipeline
4. **Manual override** - User sets `QUICK_TEST=false`

## Cache Architecture

```
NFS Cache (shared across builders):
/nfs/ci-cache/haf/
├── 9ce4243d23b6f27ab9023a401ada586a856b8848.tar   # Cached replay data
├── abc123def456789.tar
└── ...

Local Cache (per-builder):
/cache/
├── haf_9ce4243d23b6f27ab9023a401ada586a856b8848/  # Extracted from NFS
│   └── datadir/
│       ├── blockchain/
│       └── haf_db_store/
└── haf_pipeline_12345/                             # Pipeline-specific copy
    └── datadir/
```

## Troubleshooting

### "No cached data found"

The auto-skip mode couldn't find any cached replay data:
1. Verify NFS is accessible from the runner (`data-cache-storage` tag)
2. Check that `/nfs/ci-cache/haf/` contains `.tar` files
3. Run a full pipeline first to populate the cache

### "Cache not found for commit X"

In manual QUICK_TEST mode, the specified commit doesn't have cached data:
1. Use `./scripts/ci-helpers/list-haf-caches.sh` to find valid cache keys
2. Or use a different, cached commit

### "Build still running despite only test changes"

Check if any of your changes touched files outside tests/docs:
- `git diff --name-only origin/develop...HEAD`
- SQL files (`.sql`) require replay, so they trigger full build
- Submodule updates (`.gitmodules`) require full build

## Best Practices

1. **Keep test changes separate** - Don't mix test fixes with core changes in the same MR
2. **Use recent cache keys** - Older caches may have schema differences
3. **Verify locally first** - Run tests locally before pushing to save CI time
4. **Tag jobs correctly** - Test jobs need `data-cache-storage` tag for NFS access

## See Also

- `scripts/ci-helpers/cache-manager.sh` - NFS cache management
- `scripts/ci-helpers/list-haf-caches.sh` - List available cache keys
