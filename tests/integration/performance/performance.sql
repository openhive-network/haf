-- =============================================================================
-- HAF Performance Benchmark Queries
-- =============================================================================
--
-- PURPOSE:
--   Measure query performance for representative HAF application queries to
--   establish baseline metrics and track the impact of schema changes,
--   particularly during the unified table architecture refactoring.
--
-- USAGE:
--   psql -U haf_admin -d haf_block_log -f performance.sql
--
-- OUTPUT:
--   Summary table with timing metrics for each query:
--   - Execution time (ms) - actual query execution time
--   - Planning time (ms) - query plan generation time
--   - Rows returned - number of result rows
--   - Buffers hit - pages found in shared buffer cache
--   - Buffers read - pages read from disk
--
-- =============================================================================
-- WHY THESE QUERIES WERE CHOSEN
-- =============================================================================
--
-- This benchmark covers the most critical query patterns used by HAF applications.
-- Queries were selected based on analysis of actual application code from:
--   - HAfAH (hive/HAfAH) - account_history_api implementation
--   - Reputation Tracker (hive/reputation_tracker) - reputation calculation
--   - Balance Tracker (hive/balance_tracker) - account balance tracking
--   - Hivemind (hive/hivemind) - social layer APIs
--   - HAF Block Explorer (hive/haf_block_explorer) - blockchain exploration
--   - Block API (hive/tests_api/benchmarks/blocks_api) - hived block retrieval API
--
-- QUERY PATTERN CATEGORIES:
--
-- 1. SYNC PATTERNS (batch processing during blockchain synchronization):
--    - Block range iteration (e.g., WHERE block_num BETWEEN X AND Y)
--    - Operation type filtering (e.g., WHERE op_type_id = 2)
--    - These run continuously during sync and must be highly optimized
--
-- 2. API PATTERNS (single-request user queries):
--    - Point lookups (e.g., WHERE block_num = X, WHERE name = 'account')
--    - Account history retrieval (ORDER BY ... DESC LIMIT N)
--    - Transaction hash lookups
--    - These affect API response times directly
--
-- 3. AGGREGATION PATTERNS (analytics and statistics):
--    - COUNT/GROUP BY queries for dashboards
--    - Most active accounts, operation distributions
--    - These are less frequent but can be expensive
--
-- =============================================================================
-- APPLICATIONS AND THEIR KEY QUERY PATTERNS
-- =============================================================================
--
-- SECTION 1: HAF CORE VIEWS
--   All HAF applications depend on these views (blocks_view, operations_view,
--   transactions_view, accounts_view, account_operations_view). Performance
--   regressions here affect ALL downstream applications.
--
-- SECTION 2: HAfAH (account_history_api)
--   Primary API for wallets and block explorers. Key operations:
--   - get_account_history: Most called API, retrieves account operations
--   - get_ops_in_block: Returns all operations in a specific block
--   - get_transaction: Lookup transaction by hash
--   Source: hive/HAfAH/haf/database/sql/hafah_python/
--
-- SECTION 3: REPUTATION TRACKER
--   Processes vote-related operations to calculate account reputation scores.
--   Key patterns:
--   - Filtering by operation types (72=effective_comment_vote, 17=delete_comment)
--   - Batch account name resolution
--   Source: hive/reputation_tracker/
--
-- SECTION 4: BALANCE TRACKER
--   Maintains account balances by processing transfer and stake operations.
--   Key patterns:
--   - Filtering transfer operations (type 2)
--   - Reading DGPO (dynamic global properties) for VESTS->HIVE conversion
--   Source: hive/balance_tracker/
--
-- SECTION 5: HIVEMIND (Social Features)
--   Processes social operations (follows, reblogs, comments) for community APIs.
--   Key patterns:
--   - custom_json operations (type 18) for follow/mute
--   - comment operations (type 1) for content
--   Source: hive/hivemind/hive/indexer/
--
-- SECTION 6: BLOCK EXPLORER
--   Provides search and browsing capabilities across blockchain data.
--   Key patterns:
--   - Pagination through blocks
--   - Filtering by operation type or account
--   - Witness statistics
--   Source: hive/haf_block_explorer/
--
-- SECTION 7: AGGREGATIONS
--   Common analytical queries used by dashboards and statistics endpoints.
--   Tests GROUP BY performance on large datasets.
--
-- SECTION 8: BLOCK API (hived block_api)
--   Core block retrieval API provided by hived, tested via JMeter benchmarks.
--   Key patterns:
--   - get_block: Full block retrieval with operations/transactions
--   - get_block_header: Lightweight header-only retrieval
--   - get_block_range: Batch block retrieval for sync applications
--   Source: hive/tests/python/hive-local-tools/tests_api/benchmarks/blocks_api/
--   CI Job: block_api_tests (uses JMeter with perf_5M_*.csv datasets)
--
-- =============================================================================

\pset pager off
\set QUIET on

-- Set statement timeout to 60 seconds to avoid hanging on slow queries
SET statement_timeout = '60s';

-- Create temporary table to store benchmark results
DROP TABLE IF EXISTS _perf_results;
CREATE TEMP TABLE _perf_results (
    id SERIAL PRIMARY KEY,
    section TEXT NOT NULL,
    query_name TEXT NOT NULL,
    exec_time_ms NUMERIC(12,3),
    plan_time_ms NUMERIC(12,3),
    rows_returned BIGINT,
    buffers_hit BIGINT,
    buffers_read BIGINT
);

-- Function to run a query and capture metrics from EXPLAIN ANALYZE JSON output
CREATE OR REPLACE FUNCTION _run_benchmark(
    p_section TEXT,
    p_query_name TEXT,
    p_query TEXT
) RETURNS VOID AS $$
DECLARE
    v_explain_json JSONB;
    v_exec_time NUMERIC;
    v_plan_time NUMERIC;
    v_rows BIGINT;
    v_buffers_hit BIGINT;
    v_buffers_read BIGINT;
BEGIN
    -- Run EXPLAIN ANALYZE with JSON output
    EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' || p_query INTO v_explain_json;

    -- Extract metrics from JSON
    v_exec_time := (v_explain_json->0->>'Execution Time')::NUMERIC;
    v_plan_time := (v_explain_json->0->>'Planning Time')::NUMERIC;
    v_rows := COALESCE((v_explain_json->0->'Plan'->>'Actual Rows')::BIGINT, 0);
    v_buffers_hit := COALESCE((v_explain_json->0->'Plan'->>'Shared Hit Blocks')::BIGINT, 0);
    v_buffers_read := COALESCE((v_explain_json->0->'Plan'->>'Shared Read Blocks')::BIGINT, 0);

    -- Store results
    INSERT INTO _perf_results (section, query_name, exec_time_ms, plan_time_ms, rows_returned, buffers_hit, buffers_read)
    VALUES (p_section, p_query_name, v_exec_time, v_plan_time, v_rows, v_buffers_hit, v_buffers_read);

    -- Progress indicator
    RAISE NOTICE 'Completed: % - % (% ms)', p_section, p_query_name, ROUND(v_exec_time, 3);

EXCEPTION
    WHEN query_canceled THEN
        -- Query timed out
        INSERT INTO _perf_results (section, query_name, exec_time_ms, plan_time_ms, rows_returned, buffers_hit, buffers_read)
        VALUES (p_section, p_query_name, -1, -1, -1, -1, -1);
        RAISE NOTICE 'TIMEOUT: % - % (exceeded 60s)', p_section, p_query_name;
    WHEN OTHERS THEN
        -- Other error
        INSERT INTO _perf_results (section, query_name, exec_time_ms, plan_time_ms, rows_returned, buffers_hit, buffers_read)
        VALUES (p_section, p_query_name, -2, -2, -2, -2, -2);
        RAISE NOTICE 'ERROR: % - % (%)', p_section, p_query_name, SQLERRM;
END;
$$ LANGUAGE plpgsql;

\set QUIET off
\echo '============================================================================='
\echo 'HAF PERFORMANCE BENCHMARK'
\echo '============================================================================='
\echo 'Running benchmark queries...'
\echo ''

-- =============================================================================
-- SECTION 1: HAF CORE VIEW QUERIES
-- =============================================================================

SELECT _run_benchmark('1.CORE', '1.1 blocks_view recent 100',
    'SELECT num, hash, created_at, producer_account_id
     FROM hive.blocks_view ORDER BY num DESC LIMIT 100');

SELECT _run_benchmark('1.CORE', '1.2 blocks_view by num',
    'SELECT num, hash, created_at, producer_account_id
     FROM hive.blocks_view WHERE num = 25000000');

SELECT _run_benchmark('1.CORE', '1.3 blocks_view range 1K',
    'SELECT num, hash, created_at FROM hive.blocks_view
     WHERE num BETWEEN 20000000 AND 20001000 ORDER BY num');

SELECT _run_benchmark('1.CORE', '1.4 operations_view by block',
    'SELECT id, trx_in_block, op_pos, op_type_id, body_binary
     FROM hive.operations_view WHERE block_num = 25000000');

SELECT _run_benchmark('1.CORE', '1.5 operations_view type+range',
    'SELECT id, block_num, trx_in_block FROM hive.operations_view
     WHERE block_num BETWEEN 20000000 AND 20001000 AND op_type_id = 0 LIMIT 1000');

SELECT _run_benchmark('1.CORE', '1.6 transactions_view by block',
    'SELECT trx_hash, trx_in_block, expiration
     FROM hive.transactions_view WHERE block_num = 25000000');

SELECT _run_benchmark('1.CORE', '1.7 transactions_view by hash',
    'SELECT block_num, trx_in_block, ref_block_num, ref_block_prefix
     FROM hive.transactions_view WHERE trx_hash = (
       SELECT trx_hash FROM hive.transactions_view
       WHERE block_num = 25000000 AND trx_in_block = 0 LIMIT 1)');

SELECT _run_benchmark('1.CORE', '1.8 accounts_view by name',
    'SELECT id, name FROM hive.accounts_view WHERE name = ''blocktrades''');

SELECT _run_benchmark('1.CORE', '1.9 account_operations last 100',
    'SELECT ao.account_op_seq_no, ao.block_num, ao.operation_id
     FROM hive.account_operations_view ao
     WHERE ao.account_id = (SELECT id FROM hive.accounts_view WHERE name = ''blocktrades'' LIMIT 1)
     ORDER BY ao.account_op_seq_no DESC LIMIT 100');

-- =============================================================================
-- SECTION 2: HAfAH QUERIES (account_history_api)
-- =============================================================================

SELECT _run_benchmark('2.HAFAH', '2.1 get_account_history',
    'WITH account_info AS (SELECT id FROM hive.accounts_view WHERE name = ''blocktrades'' LIMIT 1),
     filtered_ops AS (
       SELECT ao.account_op_seq_no, ao.operation_id, ao.block_num
       FROM hive.account_operations_view ao
       JOIN account_info ai ON ao.account_id = ai.id
       ORDER BY ao.account_op_seq_no DESC LIMIT 100)
     SELECT fo.account_op_seq_no, fo.block_num, o.trx_in_block, o.op_pos, o.body_binary, b.created_at
     FROM filtered_ops fo
     JOIN hive.operations_view o ON o.id = fo.operation_id
     JOIN hive.blocks_view b ON b.num = fo.block_num');

SELECT _run_benchmark('2.HAFAH', '2.2 get_ops_in_block',
    'SELECT COALESCE(encode(t.trx_hash, ''hex''), ''0000000000000000000000000000000000000000'') as trx_id,
       o.trx_in_block, o.op_pos, ot.is_virtual, b.created_at, o.body_binary
     FROM hive.operations_view o
     JOIN hive.blocks_view b ON b.num = o.block_num
     JOIN hafd.operation_types ot ON ot.id = o.op_type_id
     LEFT JOIN hive.transactions_view t ON t.block_num = o.block_num AND t.trx_in_block = o.trx_in_block
     WHERE o.block_num = 25000000 ORDER BY o.id');

SELECT _run_benchmark('2.HAFAH', '2.3 get_transaction',
    'WITH target_tx AS (
       SELECT block_num, trx_in_block, trx_hash FROM hive.transactions_view
       WHERE block_num = 25000000 AND trx_in_block = 0 LIMIT 1)
     SELECT t.trx_hash, t.block_num, t.trx_in_block, o.op_pos, o.body_binary, b.created_at
     FROM target_tx t
     JOIN hive.operations_view o ON o.block_num = t.block_num AND o.trx_in_block = t.trx_in_block
     JOIN hive.blocks_view b ON b.num = t.block_num');

-- =============================================================================
-- SECTION 3: REPUTATION TRACKER QUERIES
-- =============================================================================

SELECT _run_benchmark('3.REPUTATION', '3.1 vote ops in range',
    'SELECT o.id, o.block_num, o.body_binary FROM hive.operations_view o
     WHERE o.op_type_id IN (72, 17, 61) AND o.block_num BETWEEN 20000000 AND 20001000
     ORDER BY o.id');

SELECT _run_benchmark('3.REPUTATION', '3.2 batch account lookup',
    'SELECT id, name FROM hive.accounts_view
     WHERE name IN (''blocktrades'', ''steemit'', ''dan'', ''ned'', ''berniesanders'')');

-- =============================================================================
-- SECTION 4: BALANCE TRACKER QUERIES
-- =============================================================================

SELECT _run_benchmark('4.BALANCE', '4.1 transfer ops in range',
    'SELECT o.id, o.block_num, o.body_binary FROM hive.operations_view o
     WHERE o.op_type_id = 2 AND o.block_num BETWEEN 20000000 AND 20001000
     ORDER BY o.id');

SELECT _run_benchmark('4.BALANCE', '4.2 latest DGPO',
    'SELECT num, total_vesting_fund_hive, total_vesting_shares
     FROM hive.blocks_view ORDER BY num DESC LIMIT 1');

-- =============================================================================
-- SECTION 5: HIVEMIND QUERIES (Social Features)
-- =============================================================================

SELECT _run_benchmark('5.HIVEMIND', '5.1 custom_json for account',
    'SELECT ao.block_num, ao.operation_id, o.body_binary
     FROM hive.account_operations_view ao
     JOIN hive.operations_view o ON o.id = ao.operation_id
     WHERE ao.account_id = (SELECT id FROM hive.accounts_view WHERE name = ''blocktrades'' LIMIT 1)
       AND o.op_type_id = 18
     ORDER BY ao.account_op_seq_no DESC LIMIT 100');

SELECT _run_benchmark('5.HIVEMIND', '5.2 comment ops for author',
    'SELECT ao.block_num, ao.operation_id, o.body_binary
     FROM hive.account_operations_view ao
     JOIN hive.operations_view o ON o.id = ao.operation_id
     WHERE ao.account_id = (SELECT id FROM hive.accounts_view WHERE name = ''blocktrades'' LIMIT 1)
       AND o.op_type_id = 1
     ORDER BY ao.account_op_seq_no DESC LIMIT 50');

-- =============================================================================
-- SECTION 6: BLOCK EXPLORER QUERIES
-- =============================================================================

SELECT _run_benchmark('6.EXPLORER', '6.1 paginate blocks',
    'SELECT num, hash, created_at FROM hive.blocks_view
     ORDER BY num DESC LIMIT 20 OFFSET 0');

SELECT _run_benchmark('6.EXPLORER', '6.2 blocks with vote ops',
    'SELECT DISTINCT o.block_num FROM hive.operations_view o
     WHERE o.op_type_id = 0 AND o.block_num BETWEEN 20000000 AND 20010000
     ORDER BY o.block_num DESC LIMIT 20');

SELECT _run_benchmark('6.EXPLORER', '6.3 blocks for account',
    'SELECT DISTINCT ao.block_num FROM hive.account_operations_view ao
     WHERE ao.account_id = (SELECT id FROM hive.accounts_view WHERE name = ''blocktrades'' LIMIT 1)
       AND ao.block_num BETWEEN 20000000 AND 25000000
     ORDER BY ao.block_num DESC LIMIT 20');

SELECT _run_benchmark('6.EXPLORER', '6.4 tx count per block',
    'SELECT block_num, COUNT(*) as trx_count FROM hive.transactions_view
     WHERE block_num BETWEEN 20000000 AND 20001000
     GROUP BY block_num ORDER BY block_num');

SELECT _run_benchmark('6.EXPLORER', '6.5 witness statistics',
    'SELECT a.name as witness, COUNT(*) as blocks_produced
     FROM hive.blocks_view b
     JOIN hive.accounts_view a ON a.id = b.producer_account_id
     WHERE b.num BETWEEN 20000000 AND 20100000
     GROUP BY a.name ORDER BY blocks_produced DESC LIMIT 21');

-- =============================================================================
-- SECTION 7: AGGREGATION QUERIES
-- =============================================================================

SELECT _run_benchmark('7.AGGREGATE', '7.1 op type distribution',
    'SELECT ot.name, COUNT(*) as op_count FROM hive.operations_view o
     JOIN hafd.operation_types ot ON ot.id = o.op_type_id
     WHERE o.block_num BETWEEN 20000000 AND 20010000
     GROUP BY ot.name ORDER BY op_count DESC LIMIT 20');

SELECT _run_benchmark('7.AGGREGATE', '7.2 most active accounts',
    'SELECT a.name, COUNT(*) as op_count FROM hive.account_operations_view ao
     JOIN hive.accounts_view a ON a.id = ao.account_id
     WHERE ao.block_num BETWEEN 20000000 AND 20010000
     GROUP BY a.name ORDER BY op_count DESC LIMIT 20');

-- =============================================================================
-- SECTION 8: BLOCK API QUERIES (hived block_api)
-- =============================================================================

SELECT _run_benchmark('8.BLOCK_API', '8.1 get_block full',
    'SELECT b.num, b.hash, b.prev, b.created_at, b.producer_account_id,
       b.transaction_merkle_root, b.extensions, b.witness_signature, b.signing_key
     FROM hive.blocks_view b WHERE b.num = 25000000');

SELECT _run_benchmark('8.BLOCK_API', '8.2 get_block with ops',
    'WITH block_data AS (
       SELECT num, hash, prev, created_at, producer_account_id
       FROM hive.blocks_view WHERE num = 25000000)
     SELECT bd.*, o.id as op_id, o.trx_in_block, o.op_pos, o.op_type_id, o.body_binary
     FROM block_data bd
     LEFT JOIN hive.operations_view o ON o.block_num = bd.num
     ORDER BY o.trx_in_block, o.op_pos');

SELECT _run_benchmark('8.BLOCK_API', '8.3 get_block with txs',
    'SELECT b.num, b.hash, b.created_at, t.trx_hash, t.trx_in_block,
       t.ref_block_num, t.ref_block_prefix, t.expiration
     FROM hive.blocks_view b
     LEFT JOIN hive.transactions_view t ON t.block_num = b.num
     WHERE b.num = 25000000 ORDER BY t.trx_in_block');

SELECT _run_benchmark('8.BLOCK_API', '8.4 get_block_header',
    'SELECT b.num, b.prev, b.created_at, b.producer_account_id, b.transaction_merkle_root
     FROM hive.blocks_view b WHERE b.num = 25000000');

SELECT _run_benchmark('8.BLOCK_API', '8.5 get_block_range 10',
    'SELECT b.num, b.hash, b.prev, b.created_at, b.producer_account_id
     FROM hive.blocks_view b
     WHERE b.num >= 20000000 AND b.num < 20000010 ORDER BY b.num');

SELECT _run_benchmark('8.BLOCK_API', '8.6 get_block_range 50',
    'SELECT b.num, b.hash, b.prev, b.created_at, b.producer_account_id
     FROM hive.blocks_view b
     WHERE b.num >= 20000000 AND b.num < 20000050 ORDER BY b.num');

SELECT _run_benchmark('8.BLOCK_API', '8.7 get_block_range+ops',
    'SELECT b.num as block_num, b.hash, b.created_at,
       o.id as op_id, o.trx_in_block, o.op_pos, o.op_type_id, o.body_binary
     FROM hive.blocks_view b
     LEFT JOIN hive.operations_view o ON o.block_num = b.num
     WHERE b.num >= 20000000 AND b.num < 20000010
     ORDER BY b.num, o.trx_in_block, o.op_pos');

SELECT _run_benchmark('8.BLOCK_API', '8.8 random block access',
    'SELECT num, hash, created_at, producer_account_id
     FROM hive.blocks_view WHERE num IN (4139328, 3890821, 4694222, 3609093, 4029605)');

-- =============================================================================
-- RESULTS SUMMARY
-- =============================================================================

\echo ''
\echo '============================================================================='
\echo 'PERFORMANCE BENCHMARK RESULTS'
\echo '============================================================================='
\echo ''

-- Summary table sorted by execution time (slowest first)
SELECT
    section,
    query_name,
    CASE
        WHEN exec_time_ms = -1 THEN '    TIMEOUT'
        WHEN exec_time_ms = -2 THEN '      ERROR'
        ELSE LPAD(TO_CHAR(exec_time_ms, 'FM999990.000'), 10, ' ') || ' ms'
    END AS exec_time,
    CASE
        WHEN plan_time_ms < 0 THEN '       N/A'
        ELSE LPAD(TO_CHAR(plan_time_ms, 'FM999990.000'), 8, ' ') || ' ms'
    END AS plan_time,
    CASE WHEN rows_returned < 0 THEN 'N/A' ELSE TO_CHAR(rows_returned, 'FM999999999') END AS rows,
    CASE WHEN buffers_hit < 0 THEN 'N/A' ELSE TO_CHAR(buffers_hit, 'FM999999999') END AS buf_hit,
    CASE WHEN buffers_read < 0 THEN 'N/A' ELSE TO_CHAR(buffers_read, 'FM999999999') END AS buf_read
FROM _perf_results
ORDER BY exec_time_ms DESC;

\echo ''
\echo '============================================================================='
\echo 'SUMMARY STATISTICS'
\echo '============================================================================='
\echo ''

-- Overall statistics
SELECT
    COUNT(*) AS total_queries,
    ROUND(SUM(exec_time_ms)::NUMERIC, 3) || ' ms' AS total_exec_time,
    ROUND(AVG(exec_time_ms)::NUMERIC, 3) || ' ms' AS avg_exec_time,
    ROUND(MIN(exec_time_ms)::NUMERIC, 3) || ' ms' AS min_exec_time,
    ROUND(MAX(exec_time_ms)::NUMERIC, 3) || ' ms' AS max_exec_time,
    SUM(buffers_hit) AS total_buf_hit,
    SUM(buffers_read) AS total_buf_read
FROM _perf_results;

\echo ''
\echo '============================================================================='
\echo 'SECTION STATISTICS'
\echo '============================================================================='
\echo ''

-- Per-section statistics
SELECT
    section,
    COUNT(*) AS queries,
    ROUND(SUM(exec_time_ms)::NUMERIC, 3) || ' ms' AS total_time,
    ROUND(AVG(exec_time_ms)::NUMERIC, 3) || ' ms' AS avg_time,
    ROUND(MAX(exec_time_ms)::NUMERIC, 3) || ' ms' AS max_time
FROM _perf_results
GROUP BY section
ORDER BY SUM(exec_time_ms) DESC;

\echo ''
\echo '============================================================================='
\echo 'TOP 10 SLOWEST QUERIES'
\echo '============================================================================='
\echo ''

SELECT
    section,
    query_name,
    ROUND(exec_time_ms::NUMERIC, 3) || ' ms' AS exec_time,
    rows_returned AS rows
FROM _perf_results
ORDER BY exec_time_ms DESC
LIMIT 10;

\echo ''
\echo '============================================================================='
\echo 'BENCHMARK COMPLETE'
\echo '============================================================================='

-- Cleanup
DROP FUNCTION IF EXISTS _run_benchmark(TEXT, TEXT, TEXT);
DROP TABLE IF EXISTS _perf_results;
