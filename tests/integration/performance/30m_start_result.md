# HAF Performance Benchmark Results - 30M Blocks Baseline

**Date:** 2026-01-29
**Database:** haf_block_log on hive-6.pl.syncad.com
**Blocks:** 30,000,000
**HAF Branch:** mi/refactoring_reversible_cc_squashed2
**Timeout:** 60 seconds per query

## Summary Statistics

| Metric | Value |
|--------|-------|
| Total Queries | 33 |
| Completed | 28 |
| Timeouts | 5 |
| Total Exec Time | 11,633 ms |
| Avg Exec Time | 352.5 ms |
| Min Exec Time | 0.024 ms |
| Max Exec Time | 9,269.9 ms |

## Full Results (sorted by execution time)

| Section | Query | Exec Time | Plan Time | Rows | Buf Hit | Buf Read |
|---------|-------|-----------|-----------|------|---------|----------|
| 6.EXPLORER | 6.3 blocks for account | 9,269.920 ms | 0.485 ms | 20 | 7,154,392 | 816,761 |
| 6.EXPLORER | 6.5 witness statistics | 824.609 ms | 1.134 ms | 21 | 2,203,081 | 1,176 |
| 3.REPUTATION | 3.1 vote ops in range | 457.595 ms | 0.141 ms | 29,741 | 332,274 | 2,708 |
| 6.EXPLORER | 6.4 tx count per block | 180.743 ms | 0.146 ms | 1,001 | 276,011 | 1,279 |
| 2.HAFAH | 2.2 get_ops_in_block | 163.722 ms | 2.341 ms | 53 | 776 | 20 |
| 2.HAFAH | 2.3 get_transaction | 125.908 ms | 1.834 ms | 2 | 41 | 0 |
| 1.CORE | 1.4 operations_view by block | 102.784 ms | 2.703 ms | 53 | 425 | 7 |
| 8.BLOCK_API | 8.7 get_block_range+ops | 98.289 ms | 1.459 ms | 987 | 11,282 | 52 |
| 1.CORE | 1.5 operations_view type+range | 93.341 ms | 0.143 ms | 1,000 | 10,417 | 179 |
| 4.BALANCE | 4.1 transfer ops in range | 92.671 ms | 0.114 ms | 3,152 | 39,801 | 8 |
| 8.BLOCK_API | 8.2 get_block with ops | 88.739 ms | 0.193 ms | 53 | 435 | 10 |
| 6.EXPLORER | 6.2 blocks with vote ops | 81.015 ms | 0.123 ms | 20 | 5,289 | 73 |
| 1.CORE | 1.9 account_operations last 100 | 22.865 ms | 1.353 ms | 100 | 1,311 | 426 |
| 1.CORE | 1.1 blocks_view recent 100 | 8.929 ms | 5.197 ms | 100 | 503 | 6 |
| 8.BLOCK_API | 8.3 get_block with txs | 7.444 ms | 0.209 ms | 35 | 185 | 6 |
| 1.CORE | 1.6 transactions_view by block | 6.219 ms | 2.244 ms | 35 | 175 | 6 |
| 3.REPUTATION | 3.2 batch account lookup | 3.854 ms | 0.297 ms | 5 | 59 | 25 |
| 1.CORE | 1.3 blocks_view range 1K | 3.580 ms | 0.088 ms | 1,001 | 5,006 | 47 |
| 8.BLOCK_API | 8.8 random block access | 2.792 ms | 0.130 ms | 5 | 35 | 15 |
| 1.CORE | 1.8 accounts_view by name | 1.599 ms | 1.323 ms | 1 | 10 | 8 |
| 1.CORE | 1.7 transactions_view by hash | 0.975 ms | 0.205 ms | 1 | 19 | 5 |
| 1.CORE | 1.2 blocks_view by num | 0.518 ms | 0.112 ms | 1 | 7 | 3 |
| 8.BLOCK_API | 8.6 get_block_range 50 | 0.103 ms | 0.085 ms | 50 | 257 | 0 |
| 6.EXPLORER | 6.1 paginate blocks | 0.095 ms | 0.133 ms | 20 | 104 | 1 |
| 8.BLOCK_API | 8.5 get_block_range 10 | 0.044 ms | 0.087 ms | 10 | 56 | 0 |
| 8.BLOCK_API | 8.1 get_block full | 0.042 ms | 1.217 ms | 1 | 6 | 4 |
| 4.BALANCE | 4.2 latest DGPO | 0.036 ms | 0.506 ms | 1 | 10 | 0 |
| 8.BLOCK_API | 8.4 get_block_header | 0.024 ms | 0.092 ms | 1 | 10 | 0 |
| 7.AGGREGATE | 7.2 most active accounts | TIMEOUT | N/A | N/A | N/A | N/A |
| 5.HIVEMIND | 5.2 comment ops for author | TIMEOUT | N/A | N/A | N/A | N/A |
| 2.HAFAH | 2.1 get_account_history | TIMEOUT | N/A | N/A | N/A | N/A |
| 7.AGGREGATE | 7.1 op type distribution | TIMEOUT | N/A | N/A | N/A | N/A |
| 5.HIVEMIND | 5.1 custom_json for account | TIMEOUT | N/A | N/A | N/A | N/A |

## Section Statistics

| Section | Queries | Total Time | Avg Time | Max Time |
|---------|---------|------------|----------|----------|
| 6.EXPLORER | 5 | 10,356.4 ms | 2,071.3 ms | 9,269.9 ms |
| 3.REPUTATION | 2 | 461.4 ms | 230.7 ms | 457.6 ms |
| 2.HAFAH | 3 | 288.6 ms | 96.2 ms | 163.7 ms |
| 1.CORE | 9 | 240.8 ms | 26.8 ms | 102.8 ms |
| 8.BLOCK_API | 8 | 197.5 ms | 24.7 ms | 98.3 ms |
| 4.BALANCE | 2 | 92.7 ms | 46.4 ms | 92.7 ms |
| 7.AGGREGATE | 2 | TIMEOUT | N/A | N/A |
| 5.HIVEMIND | 2 | TIMEOUT | N/A | N/A |

## Top 10 Slowest Queries

| Rank | Section | Query | Exec Time | Rows |
|------|---------|-------|-----------|------|
| 1 | 6.EXPLORER | blocks for account | 9,269.9 ms | 20 |
| 2 | 6.EXPLORER | witness statistics | 824.6 ms | 21 |
| 3 | 3.REPUTATION | vote ops in range | 457.6 ms | 29,741 |
| 4 | 6.EXPLORER | tx count per block | 180.7 ms | 1,001 |
| 5 | 2.HAFAH | get_ops_in_block | 163.7 ms | 53 |
| 6 | 2.HAFAH | get_transaction | 125.9 ms | 2 |
| 7 | 1.CORE | operations_view by block | 102.8 ms | 53 |
| 8 | 8.BLOCK_API | get_block_range+ops | 98.3 ms | 987 |
| 9 | 1.CORE | operations_view type+range | 93.3 ms | 1,000 |
| 10 | 4.BALANCE | transfer ops in range | 92.7 ms | 3,152 |

## Key Findings

### Fast Queries (< 1ms)
- `get_block_header` - 0.024 ms
- `latest DGPO` - 0.036 ms
- `get_block full` - 0.042 ms
- `get_block_range 10` - 0.044 ms
- `paginate blocks` - 0.095 ms
- `get_block_range 50` - 0.103 ms

### Problem Queries (Timeouts > 60s)
1. **get_account_history** - account_operations_view with JOINs to operations_view
2. **custom_json for account** - account_operations_view filtered by op_type
3. **comment ops for author** - account_operations_view filtered by op_type
4. **op type distribution** - GROUP BY on operations_view (10K block range)
5. **most active accounts** - GROUP BY on account_operations_view (10K block range)

### Performance Issues Identified
1. **account_operations_view** queries are extremely slow when filtering by account
2. **6.3 blocks for account** scanned 7.1M buffer pages for just 20 rows
3. **Aggregations** over large ranges timeout even with 10K block window
4. **JOINs between account_operations_view and operations_view** are problematic

### Well-Performing Patterns
- Block API single-block lookups (< 1ms)
- Block range queries without JOINs (< 1ms)
- Operations by block_num (100ms range)
- Transaction lookups by hash (< 1ms)
