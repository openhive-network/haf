# HAF (Hive Application Framework) - Claude Code Instructions

## Project Overview

HAF is the Hive Application Framework - a PostgreSQL-based indexing layer for the Hive blockchain. It runs alongside hived to provide SQL access to blockchain data for applications.

## Quick Test Mode

When testing changes that don't require rebuilding HAF or replaying data (e.g., SQL changes, test fixes), use Quick Test Mode to dramatically speed up CI iteration.

### Quick Reference

```bash
# Find available cache keys
./scripts/ci-helpers/list-haf-caches.sh --recent

# Or via SSH
ssh -A steem-18 "ssh hive-builder-10 'ls -lt /nfs/ci-cache/haf/*.tar | head -5'"
```

### Using Quick Test Mode

**Option 1: CI Variables**
Go to CI/CD → Run Pipeline and set:
```
QUICK_TEST=true
QUICK_TEST_HAF_COMMIT=<sha-from-cache-list>
```

**Option 2: Minimal CI Configuration**
Copy `scripts/ci-helpers/examples/quick-test-example.gitlab-ci.yml` to `.gitlab-ci.yml` and update the `QUICK_TEST_HAF_COMMIT` variable.

See `docs/QUICK-TEST-MODE.md` for full documentation.

## CI/CD

### Pipeline Structure

```
Phase 1: Build & Prepare
├── haf_image_build (mainnet, testnet, mirrornet)
├── prepare_haf_data (replay 5M blocks)
├── hfm_functional_tests
└── verify_poetry_lock_sanity

Phase 2: Tests (parallel, depend on Phase 1)
├── haf_system_tests
├── applications_system_tests
├── replay_* jobs (various filter configurations)
├── dead_app_auto_detach
└── start_haf_as_service
```

### Key CI Files

- `.gitlab-ci.yml` - Main CI configuration
- `scripts/ci-helpers/prepare_data_image_job.yml` - Data preparation templates
- `scripts/ci-helpers/cache-manager.sh` - NFS cache management
- `scripts/ci-helpers/quick-test.yml` - Quick test templates

### Cache System

HAF uses a two-tier cache for replay data:
1. **NFS cache** (`/nfs/ci-cache/haf/`) - Shared across all builders
2. **Local cache** (`/cache/`) - Per-builder extraction

Cache keys are HAF commit SHAs. The cache-manager handles:
- NFS ↔ local synchronization
- PostgreSQL permission restoration
- Tablespace symlink fixing
- LRU eviction

## Code Style

### Python
- Use `black` formatter before pushing
- Poetry for dependency management
- Tests use pytest

```bash
cd tests/integration/haf-local-tools
poetry install
poetry run black .
```

### SQL
- Use lowercase for SQL keywords
- Prefix functions with schema name
- Use `hive.` schema for core HAF objects

## Common Tasks

### Running Tests Locally

```bash
# System tests
poetry run pytest tests/integration/system/haf/ -v

# Single test
poetry run pytest tests/integration/system/haf/test_something.py::test_name -v
```

### Building HAF Image

```bash
./scripts/ci-helpers/get_image4submodule.sh . registry.gitlab.syncad.com/hive/haf HAF
```

### Checking Database State

```sql
-- Check sync status
SELECT * FROM hive.contexts;

-- Block count
SELECT COUNT(*) FROM hive.blocks;

-- Check applications
SELECT * FROM hive.registered_tables;
```

## Architecture Notes

### Key Components

- **hived** - Blockchain node (in `hive/` submodule)
- **haf_block_log** - PostgreSQL database with blockchain data
- **hfm** (HAF Fork Manager) - Manages fork handling
- **psql** - SQL interface to HAF data

### Important Directories

```
/home/haf_admin/              # HAF home in containers
/home/hived/datadir/          # Data directory
  ├── blockchain/             # Block log files
  └── haf_db_store/           # PostgreSQL data
      ├── pgdata/             # PG data directory
      └── tablespace/         # PG tablespace
```

## Troubleshooting

### Service Container Issues

If HAF service container fails to connect:
1. Check `PG_ACCESS` variable includes necessary trust rules
2. Verify `DATA_SOURCE` points to correct cache path
3. Check service logs: `docker logs <container>`

### Permission Issues

PostgreSQL requires strict permissions on pgdata (mode 700). The cache-manager handles this, but if issues occur:
```bash
sudo chmod 700 /path/to/pgdata
sudo chown -R 105:105 /path/to/pgdata  # UID 105 = postgres in containers
```

### Symlink Issues

Tablespace symlinks can break when data is moved. Fix with:
```bash
# cache-manager does this automatically, but manually:
cd pgdata/pg_tblspc/
rm 16396  # or whatever OID
ln -s /new/path/to/tablespace 16396
```
