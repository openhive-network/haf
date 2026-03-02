-- =============================================================================
-- BRIN Index Optimizations for HAF Block Explorer Performance
-- =============================================================================
-- This file adds BRIN indexes to accelerate block range queries in HAF tables.
-- BRIN indexes are ideal for sequential block processing as they leverage
-- data correlation and have minimal storage overhead (~0.1% of B-tree size).
--
-- Target: 50% faster haf_block_explorer sync to 5M blocks
-- Storage constraint: <10% database growth (BRIN achieves <1% growth)
-- =============================================================================

-- =============================================================================
-- Change 1: BRIN Index on hafd.operations(block_num)
-- =============================================================================
-- operations is the largest table and most frequently queried by block_explorer
-- BRIN index accelerates block-range scans during sequential sync
-- Storage estimate: ~5-20 MB at 5M blocks vs ~2-5 GB for equivalent B-tree

CREATE INDEX IF NOT EXISTS idx_operations_block_num_brin
    ON hafd.operations USING brin (hafd.block_id_to_num(block_id))
    WITH (pages_per_range = 32);

COMMENT ON INDEX hafd.idx_operations_block_num_brin IS
'BRIN index for block-range queries on operations table. Optimizes sequential block processing in block_explorer sync.';

-- =============================================================================
-- Change 2: BRIN Index on hafd.transactions(block_num)
-- =============================================================================
-- transactions table has frequent block-range lookups during sync
-- Storage estimate: ~2-10 MB at 5M blocks

CREATE INDEX IF NOT EXISTS idx_transactions_block_num_brin
    ON hafd.transactions USING brin (hafd.block_id_to_num(block_id))
    WITH (pages_per_range = 32);

COMMENT ON INDEX hafd.idx_transactions_block_num_brin IS
'BRIN index for block-range queries on transactions table. Accelerates transaction lookups by block during sync.';

-- =============================================================================
-- Change 3: BRIN Index on hafd.account_operations(block_num)
-- =============================================================================
-- account_operations lookups by block are common in block explorer sync
-- Storage estimate: ~1-5 MB at 5M blocks

CREATE INDEX IF NOT EXISTS idx_account_operations_block_num_brin
    ON hafd.account_operations USING brin (hafd.block_id_to_num(block_id))
    WITH (pages_per_range = 32);

COMMENT ON INDEX hafd.idx_account_operations_block_num_brin IS
'BRIN index for block-range queries on account_operations table. Optimizes account operation queries by block.';

-- =============================================================================
-- Statistics Update for Better Query Planning
-- =============================================================================
-- Force fresh statistics after BRIN index creation to help planner
-- choose optimal execution plans

ANALYZE hafd.operations;
ANALYZE hafd.transactions;
ANALYZE hafd.account_operations;

-- =============================================================================
-- Index Creation Summary
-- =============================================================================
-- Total estimated storage growth: ~8-35 MB for all BRIN indexes
-- This represents <0.1% of typical HAF database size (~2.7TB at 5M blocks)
-- BRIN indexes have minimal write overhead during sync
-- pages_per_range=32 balances between index size and selectivity
-- =============================================================================