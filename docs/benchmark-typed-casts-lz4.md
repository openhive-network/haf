# Benchmark: Typed Casts (Option D) + LZ4 TOAST Compression

**Date:** 2026-03-11
**Server:** steem-20.syncad.com (haf-irrev-haf-1 container)
**Dataset:** `hafd.operations` blocks 80,000,001 - 81,000,000 (61,981,825 rows)

## Operation Type Distribution

| op_type_id | Operation Type | Count |
|---|---|---|
| 18 | custom_json_operation | 28,959,496 |
| 0 | vote_operation | 10,357,400 |
| 72 | effective_comment_vote_operation | 10,292,643 |
| 52 | curation_reward_operation (virtual) | 6,123,276 |
| 39 | fill_vesting_withdraw_operation (virtual) | 1,186,542 |
| 64 | producer_reward_operation (virtual) | 1,000,000 |
| 1 | comment_operation | 951,451 |
| 2 | transfer_operation | 670,506 |

## Part 1: Typed Casts vs jsonb

Each test run 3 times. Times in milliseconds.

### vote_operation (type 0, 10.4M rows)

| Method | Run 1 | Run 2 | Run 3 | Avg |
|---|---|---|---|---|
| `::jsonb -> 'value' ->> 'voter'` | 3,054 | 3,180 | 3,151 | **3,128** |
| `::hive.vote_operation).voter` | 2,948 | 2,937 | 2,975 | **2,953** |
| **Speedup** | | | | **5.6%** |

### effective_comment_vote_operation (type 72, 10.3M rows)

| Method | Run 1 | Run 2 | Run 3 | Avg |
|---|---|---|---|---|
| `::jsonb -> 'value' ->> 'voter'` | 5,031 | 5,070 | 5,040 | **5,047** |
| `::hive.effective_comment_vote_operation).voter` | 4,363 | 4,408 | 4,409 | **4,393** |
| **Speedup** | | | | **13.0%** |

### transfer_operation (type 2, 671K rows)

| Method | Run 1 | Run 2 | Run 3 | Avg |
|---|---|---|---|---|
| `::jsonb -> 'value' ->> 'from'` | 1,551 | 1,522 | 1,541 | **1,538** |
| `::hive.transfer_operation)."from"` | 1,509 | 1,540 | 1,538 | **1,529** |
| **Speedup** | | | | **0.6%** |

### comment_operation (type 1, 951K rows)

| Method | Run 1 | Run 2 | Run 3 | Avg |
|---|---|---|---|---|
| `::jsonb -> 'value' ->> 'body'` | 1,837 | 1,858 | 1,858 | **1,851** |
| `::hive.comment_operation).body` | 1,752 | 1,757 | 1,783 | **1,764** |
| **Speedup** | | | | **4.7%** |

### custom_json_operation (type 18, 29.0M rows)

| Method | Run 1 | Run 2 | Run 3 | Avg |
|---|---|---|---|---|
| `::jsonb -> 'value' ->> 'json'` | 7,923 | 8,063 | 8,125 | **8,037** |
| `::hive.custom_json_operation).json` | 8,639 | 8,679 | 8,578 | **8,632** |
| **Speedup** | | | | **-7.4% (slower!)** |

### Mixed ops - all 62M rows (jsonb only, no typed cast equivalent)

| Method | Run 1 | Run 2 | Run 3 | Avg |
|---|---|---|---|---|
| `::jsonb::text` full scan | 28,287 | 27,985 | 28,253 | **28,175** |

## Part 2: LZ4 TOAST Compression

### Storage Size

| Compression | Total Size | Bytes |
|---|---|---|
| PGLZ (default) | 12 GB | 12,562,628,608 |
| LZ4 | 11 GB | 12,290,449,408 |
| **Difference** | | **-2.2%** |

### Full Table Scan: jsonb decode (62M rows)

| Compression | Run 1 | Run 2 | Run 3 | Avg |
|---|---|---|---|---|
| PGLZ `::jsonb::text` | 27,764 | 27,966 | 27,940 | **27,890** |
| LZ4 `::jsonb::text` | 27,079 | 26,559 | 26,159 | **26,599** |
| **Speedup** | | | | **4.6%** |

### Raw Detoast (no decode, 62M rows)

| Compression | Run 1 | Run 2 | Run 3 | Avg |
|---|---|---|---|---|
| PGLZ `::bytea` | 1,668 | 1,669 | 1,700 | **1,679** |
| LZ4 `::bytea` | 1,670 | 1,704 | 1,667 | **1,680** |
| **Speedup** | | | | **0.0% (no difference)** |

### Combined: LZ4 + Typed Cast (vote_operation, 10.4M rows)

| Method | Run 1 | Run 2 | Run 3 | Avg |
|---|---|---|---|---|
| PGLZ + jsonb | 3,054 | 3,180 | 3,151 | **3,128** |
| PGLZ + typed | 2,948 | 2,937 | 2,975 | **2,953** |
| LZ4 + jsonb | 2,878 | 2,881 | 2,883 | **2,881** |
| LZ4 + typed | 2,711 | 2,678 | 2,696 | **2,695** |
| **Combined speedup (LZ4+typed vs PGLZ+jsonb)** | | | | **13.8%** |

## Key Findings

### Typed Casts

1. **Speedup varies by operation type:** 0.6% (transfer) to 13% (effective_comment_vote). The benefit is proportional to the complexity of the protobuf struct being decoded - more fields = more savings from skipping jsonb serialization.

2. **custom_json typed cast is 7.4% SLOWER** than jsonb. This is the most common op type (47% of rows). The custom_json struct has `required_auths` and `required_posting_auths` as repeated fields (arrays), which may be more expensive to decode into a composite PostgreSQL type than into jsonb.

3. **Critical limitation:** Typed casts require knowing the operation type at query time. Mixed-type scans (common in hivemind massive sync) cannot use typed casts. Each app would need per-type-id query branches.

4. **Type ID gotcha:** op_type_id values don't always map to the obvious cast name (e.g., type 72 is `effective_comment_vote_operation`, not `vote_operation`; type 0 is `vote_operation`). Apps must maintain correct mappings.

### LZ4 TOAST

1. **Minimal size reduction:** Only 2.2% smaller than PGLZ. The `body_binary` column stores protobuf-encoded data which is already compact; there's little redundancy for either compressor to exploit.

2. **Decompression speed: marginal benefit.** Raw detoast (`::bytea`) shows zero difference. With jsonb decode, LZ4 shows ~4.6% improvement, but this may be within noise since the decode cost dominates.

3. **The detoast cost is tiny** compared to decode: 1.7s raw vs 28s with jsonb decode. Decompression is only ~6% of total read cost. Even a 2x faster decompressor (LZ4's theoretical advantage) would save only ~3% end-to-end.

### Combined (LZ4 + Typed Cast)

The best-case combined benefit is **13.8%** (vote_operation with LZ4 + typed cast vs PGLZ + jsonb). For the most common operation (custom_json, 47% of rows), LZ4 provides ~4.6% benefit but typed cast is actually slower.

## Recommendations

| Approach | Benefit | Effort | Verdict |
|---|---|---|---|
| **Typed casts** | 5-13% for simple ops, **negative** for custom_json | High (app-level SQL changes, per-type branching) | **Not recommended.** Negative result on the most common op type negates gains elsewhere. |
| **LZ4 TOAST** | 2-5% | Low (`ALTER TABLE ... SET COMPRESSION lz4` + `VACUUM FULL`) | **Marginal.** The protobuf encoding is already compact, leaving little for LZ4 to improve. |
| **Combined** | Up to 14% best case, ~3-5% weighted average | High | **Not worth the complexity.** |

The bottleneck for `body_binary` reads is the protobuf-to-jsonb/type decode in C++, not decompression. Optimization efforts should focus on reducing the number of decodes needed (e.g., filtering at binary level, caching decoded results) rather than making individual decodes marginally faster.
