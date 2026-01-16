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

## HAF Ecosystem & Dependencies

HAF is a core component that many other Hive projects depend on. When making changes to HAF, consider the impact on these downstream projects.

### Direct HAF Dependencies

These projects directly use HAF (as a submodule or direct database dependency):

| Project | Repository | Description |
|---------|------------|-------------|
| **hivemind** | `hive/hivemind` | Social layer for Hive blockchain, provides community/follow/reblog APIs |
| **haf_block_explorer** | `hive/haf_block_explorer` | Block explorer built on HAF |
| **HAfAH** | `hive/HAfAH` | HAF API Helper - provides standardized API endpoints |
| **reputation_tracker** | `hive/reputation_tracker` | Tracks and calculates account reputation scores |
| **nft_tracker** | `hive/nft_tracker` | Tracks NFT-related operations and ownership |
| **balance_tracker** | `hive/balance_tracker` | Tracks account balances and token movements |
| **denser** | `hive/denser` | Frontend application for Hive |
| **haf_api_node** | `hive/haf_api_node` | HAF API node infrastructure/deployment |
| **hafsql** | `hive/hafsql` | SQL interface layer to HAF |
| **hafsql-api** | `hive/hafsql-api` | API layer for hafsql |

### Indirect HAF Dependencies

These projects depend on HAF through other projects:

| Project | Depends On | Path to HAF |
|---------|------------|-------------|
| **hivesense** | hivemind | hivesense → hivemind → HAF |
| **haf_block_explorer** | HAfAH, reputation_tracker, balance_tracker | Uses multiple HAF apps |
| **hivemind** | HAfAH, reputation_tracker | Uses helper HAF apps |
| **haf_api_node** | hivemind | Deploys hivemind which uses HAF |

### Impact of HAF Changes

When modifying HAF internals:

- **`hafd.*` schema changes** - Internal tables. Applications using `hive.*` views are isolated from these changes.
- **`hive.*` schema changes** - Public API. Changes here may require updates to dependent applications.
- **View changes** - `hive.blocks_view`, `hive.operations_view`, etc. are the stable interface for applications.
- **Function signature changes** - `hive.app_next_block()`, `hive.app_create_context()`, etc. affect all HAF applications.

### Architecture: Unified Tables with block_id

HAF uses a unified table architecture where all block data (irreversible and reversible) is stored in single tables using `block_id` encoding:

```sql
-- block_id encodes both block number and fork ID
-- block_id = (block_num << 32) | fork_id
-- Fork 0 = irreversible, Fork 1+ = reversible forks

-- Create block_id
SELECT hafd.make_block_id(block_num, fork_id);

-- Extract components
SELECT hafd.block_id_to_num(block_id);  -- Get block number
SELECT hafd.block_id_to_fork(block_id); -- Get fork ID

-- Applications use views that abstract away block_id:
SELECT * FROM hive.blocks_view;        -- Returns block_num, not block_id
SELECT * FROM hive.operations_view;    -- Filtered by context's fork
```

Key tables using `block_id`:
- `hafd.blocks` - Block headers
- `hafd.transactions` - Transactions
- `hafd.operations` - Operations
- `hafd.accounts` - Account creation records
- `hafd.account_operations` - Account-operation mappings

### Migration Example: Hivemind

Hivemind MR !992 shows the pattern for adapting to unified tables:

```sql
-- Before (old schema with block_num column)
INSERT INTO hafd.blocks (num, hash, prev, ...)
VALUES (:num, :hash, :prev, ...);

-- After (new schema with block_id)
INSERT INTO hafd.blocks (block_id, hash, prev, ...)
VALUES (hafd.make_block_id(:num, 0), :hash, :prev, ...);

-- Querying block numbers (extract from block_id)
SELECT *, hafd.block_id_to_num(block_id) AS num
FROM hafd.blocks ORDER BY block_id DESC LIMIT 1;
```

Note: Fork ID 0 is used for irreversible/massive sync data. Applications inserting mock data or during massive sync should use fork 0.

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
