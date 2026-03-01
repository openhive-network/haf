-- =============================================================================
-- Head Block Views for hive schema
-- =============================================================================
-- These views show all data including reversible blocks.
-- Canonical block selection: For each block_num, the row from the newest fork
-- (highest block_id) is canonical. Uses PK-range NOT EXISTS on pk_hive_blocks
-- for efficient deduplication:
--   NOT EXISTS (SELECT 1 FROM hafd.blocks hb2
--               WHERE hb2.block_id > row.block_id
--                 AND hb2.block_id < (((row.block_id >> 32) + 1) << 32))
-- This gives Nested Loop Anti Join with Index Only Scan instead of Hash Anti Join.
-- =============================================================================

-- =============================================================================
-- blocks_view - Canonical blocks via PK-range dedup
-- =============================================================================
-- For each block_num, returns the version with highest block_id.
CREATE OR REPLACE VIEW hive.blocks_view AS
SELECT
    hafd.block_id_to_num(hb.block_id) AS num,
    hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
    hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
    hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
    hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
    hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
FROM hafd.blocks hb
WHERE NOT EXISTS (
    SELECT 1 FROM hafd.blocks hb2
    WHERE hb2.block_id > hb.block_id
      AND hb2.block_id < (((hb.block_id >> 32) + 1) << 32)
);

-- =============================================================================
-- transactions_view - Canonical transactions via PK-range dedup
-- =============================================================================
CREATE OR REPLACE VIEW hive.transactions_view AS
SELECT
    hafd.block_id_to_num(ht.block_id) AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
WHERE NOT EXISTS (
    SELECT 1 FROM hafd.blocks hb2
    WHERE hb2.block_id > ht.block_id
      AND hb2.block_id < (((ht.block_id >> 32) + 1) << 32)
);

-- =============================================================================
-- operations_view - Canonical operations via PK-range dedup
-- =============================================================================
CREATE OR REPLACE VIEW hive.operations_view AS
SELECT
    ho.id,
    hafd.operation_id_to_block_num(ho.id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    ho.op_type_id,
    ho.body_binary,
    ho.body_binary::jsonb AS body,
    ho.custom_json_type_id
FROM hafd.operations ho
WHERE NOT EXISTS (
    SELECT 1 FROM hafd.blocks hb2
    WHERE hb2.block_id > ho.block_id
      AND hb2.block_id < (((ho.block_id >> 32) + 1) << 32)
);

-- =============================================================================
-- operations_view_extended - Canonical operations with timestamp
-- =============================================================================
CREATE OR REPLACE VIEW hive.operations_view_extended AS
SELECT
    ov.id,
    ov.block_num,
    ov.trx_in_block,
    ov.op_pos,
    ov.op_type_id,
    b.created_at AS timestamp,
    ov.body_binary,
    ov.body,
    ov.custom_json_type_id
FROM hive.operations_view ov
JOIN hive.blocks_view b ON b.num = ov.block_num;

-- =============================================================================
-- account_operations_view - Canonical account operations via PK-range dedup
-- =============================================================================
-- Two-level filtering:
-- 1. Block-level: row's block must be canonical (no newer fork for same block_num)
-- 2. Account-op level: among canonical rows, keep only highest block_id
--    per (account_id, account_op_seq_no)
CREATE OR REPLACE VIEW hive.account_operations_view AS
SELECT
    hafd.block_id_to_num(hao.block_id) AS block_num,
    hao.account_id,
    hao.transacting_account_id,
    hao.account_op_seq_no,
    hao.operation_id,
    hao.op_type_id
FROM hafd.account_operations hao
WHERE
    -- Block is canonical (no newer fork for same block_num)
    NOT EXISTS (
        SELECT 1 FROM hafd.blocks hb2
        WHERE hb2.block_id > hao.block_id
          AND hb2.block_id < (((hao.block_id >> 32) + 1) << 32)
    )
    -- No other canonical row for same (account_id, account_op_seq_no) with higher block_id
    AND NOT EXISTS (
        SELECT 1 FROM hafd.account_operations hao2
        WHERE hao2.account_id = hao.account_id
          AND hao2.account_op_seq_no = hao.account_op_seq_no
          AND hao2.block_id > hao.block_id
          AND NOT EXISTS (
              SELECT 1 FROM hafd.blocks hb3
              WHERE hb3.block_id > hao2.block_id
                AND hb3.block_id < (((hao2.block_id >> 32) + 1) << 32)
          )
    );

-- =============================================================================
-- accounts_view - Canonical accounts via PK-range dedup
-- =============================================================================
-- Shows accounts from canonical blocks or initial dump (NULL block_id).
CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT ha.id, ha.name
FROM hafd.accounts ha
WHERE
    (
        -- Block-based account from a canonical block, latest version
        ha.block_id IS NOT NULL
        AND NOT EXISTS (
            SELECT 1 FROM hafd.blocks hb2
            WHERE hb2.block_id > ha.block_id
              AND hb2.block_id < (((ha.block_id >> 32) + 1) << 32)
        )
        AND NOT EXISTS (
            SELECT 1 FROM hafd.accounts ha2
            WHERE ha2.id = ha.id
              AND ha2.block_id IS NOT NULL
              AND ha2.block_id > ha.block_id
              AND NOT EXISTS (
                  SELECT 1 FROM hafd.blocks hb3
                  WHERE hb3.block_id > ha2.block_id
                    AND hb3.block_id < (((ha2.block_id >> 32) + 1) << 32)
              )
        )
    )
    OR
    (
        -- Initial dump account (NULL block_id), only if no canonical block-based version exists
        ha.block_id IS NULL
        AND NOT EXISTS (
            SELECT 1 FROM hafd.accounts ha2
            WHERE ha2.id = ha.id
              AND ha2.block_id IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM hafd.blocks hb2
                  WHERE hb2.block_id > ha2.block_id
                    AND hb2.block_id < (((ha2.block_id >> 32) + 1) << 32)
              )
        )
    );

-- =============================================================================
-- transactions_multisig_view - Canonical multisig signatures via PK-range dedup
-- =============================================================================
CREATE OR REPLACE VIEW hive.transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
WHERE NOT EXISTS (
    SELECT 1 FROM hafd.blocks hb2
    WHERE hb2.block_id > htm.block_id
      AND hb2.block_id < (((htm.block_id >> 32) + 1) << 32)
);

-- =============================================================================
-- applied_hardforks_view - Canonical hardforks via PK-range dedup
-- =============================================================================
CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
SELECT
    hah.hardfork_num,
    hafd.block_id_to_num(hah.block_id) AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
WHERE NOT EXISTS (
    SELECT 1 FROM hafd.blocks hb2
    WHERE hb2.block_id > hah.block_id
      AND hb2.block_id < (((hah.block_id >> 32) + 1) << 32)
);

-- =============================================================================
-- Irreversible views - Only show data from irreversible blocks
-- =============================================================================
-- These views filter to blocks at or below consistent_block (irreversible).
-- Uses PK-range NOT EXISTS restricted to the irreversible range.

CREATE OR REPLACE VIEW hive.irreversible_blocks_view AS
SELECT
    hafd.block_id_to_num(hb.block_id) AS num,
    hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
    hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
    hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
    hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
    hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
FROM hafd.blocks hb
CROSS JOIN hafd.hive_state hs
WHERE hb.block_id <= hs.consistent_block
  AND NOT EXISTS (
      SELECT 1 FROM hafd.blocks hb2
      WHERE hb2.block_id > hb.block_id
        AND hb2.block_id < (((hb.block_id >> 32) + 1) << 32)
        AND hb2.block_id <= hs.consistent_block
  );

CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS
SELECT
    hafd.block_id_to_num(ht.block_id) AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
CROSS JOIN hafd.hive_state hs
WHERE ht.block_id <= hs.consistent_block
  AND NOT EXISTS (
      SELECT 1 FROM hafd.blocks hb2
      WHERE hb2.block_id > ht.block_id
        AND hb2.block_id < (((ht.block_id >> 32) + 1) << 32)
        AND hb2.block_id <= hs.consistent_block
  );

CREATE OR REPLACE VIEW hive.irreversible_operations_view AS
SELECT
    ho.id,
    hafd.operation_id_to_block_num(ho.id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    ho.op_type_id,
    ho.body_binary,
    ho.body_binary::jsonb AS body,
    ho.custom_json_type_id
FROM hafd.operations ho
CROSS JOIN hafd.hive_state hs
WHERE ho.block_id <= hs.consistent_block
  AND NOT EXISTS (
      SELECT 1 FROM hafd.blocks hb2
      WHERE hb2.block_id > ho.block_id
        AND hb2.block_id < (((ho.block_id >> 32) + 1) << 32)
        AND hb2.block_id <= hs.consistent_block
  );

CREATE OR REPLACE VIEW hive.irreversible_operations_view_extended AS
SELECT
    ov.id,
    ov.block_num,
    ov.trx_in_block,
    ov.op_pos,
    ov.op_type_id,
    hb.created_at AS timestamp,
    ov.body_binary,
    ov.body,
    ov.custom_json_type_id
FROM hive.irreversible_operations_view ov
JOIN hive.irreversible_blocks_view hb ON hb.num = ov.block_num;

CREATE OR REPLACE VIEW hive.irreversible_account_operations_view AS
SELECT
    hafd.block_id_to_num(hao.block_id) AS block_num,
    hao.account_id,
    hao.transacting_account_id,
    hao.account_op_seq_no,
    hao.operation_id,
    hao.op_type_id
FROM hafd.account_operations hao
CROSS JOIN hafd.hive_state hs
WHERE hao.block_id <= hs.consistent_block
  -- Block is canonical within irreversible range
  AND NOT EXISTS (
      SELECT 1 FROM hafd.blocks hb2
      WHERE hb2.block_id > hao.block_id
        AND hb2.block_id < (((hao.block_id >> 32) + 1) << 32)
        AND hb2.block_id <= hs.consistent_block
  )
  -- No other canonical row for same (account_id, account_op_seq_no) with higher block_id
  AND NOT EXISTS (
      SELECT 1 FROM hafd.account_operations hao2
      WHERE hao2.account_id = hao.account_id
        AND hao2.account_op_seq_no = hao.account_op_seq_no
        AND hao2.block_id > hao.block_id
        AND hao2.block_id <= hs.consistent_block
        AND NOT EXISTS (
            SELECT 1 FROM hafd.blocks hb3
            WHERE hb3.block_id > hao2.block_id
              AND hb3.block_id < (((hao2.block_id >> 32) + 1) << 32)
              AND hb3.block_id <= hs.consistent_block
        )
  );

CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS
SELECT ha.id, ha.name
FROM hafd.accounts ha
CROSS JOIN hafd.hive_state hs
WHERE
    (
        -- Block-based account from a canonical irreversible block, latest version
        ha.block_id IS NOT NULL
        AND ha.block_id <= hs.consistent_block
        AND NOT EXISTS (
            SELECT 1 FROM hafd.blocks hb2
            WHERE hb2.block_id > ha.block_id
              AND hb2.block_id < (((ha.block_id >> 32) + 1) << 32)
              AND hb2.block_id <= hs.consistent_block
        )
        AND NOT EXISTS (
            SELECT 1 FROM hafd.accounts ha2
            WHERE ha2.id = ha.id
              AND ha2.block_id IS NOT NULL
              AND ha2.block_id > ha.block_id
              AND ha2.block_id <= hs.consistent_block
              AND NOT EXISTS (
                  SELECT 1 FROM hafd.blocks hb3
                  WHERE hb3.block_id > ha2.block_id
                    AND hb3.block_id < (((ha2.block_id >> 32) + 1) << 32)
                    AND hb3.block_id <= hs.consistent_block
              )
        )
    )
    OR
    (
        -- Initial dump account (NULL block_id), only if no canonical irreversible version exists
        ha.block_id IS NULL
        AND NOT EXISTS (
            SELECT 1 FROM hafd.accounts ha2
            WHERE ha2.id = ha.id
              AND ha2.block_id IS NOT NULL
              AND ha2.block_id <= hs.consistent_block
              AND NOT EXISTS (
                  SELECT 1 FROM hafd.blocks hb2
                  WHERE hb2.block_id > ha2.block_id
                    AND hb2.block_id < (((ha2.block_id >> 32) + 1) << 32)
                    AND hb2.block_id <= hs.consistent_block
              )
        )
    );

CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
CROSS JOIN hafd.hive_state hs
WHERE htm.block_id <= hs.consistent_block
  AND NOT EXISTS (
      SELECT 1 FROM hafd.blocks hb2
      WHERE hb2.block_id > htm.block_id
        AND hb2.block_id < (((htm.block_id >> 32) + 1) << 32)
        AND hb2.block_id <= hs.consistent_block
  );

CREATE OR REPLACE VIEW hive.irreversible_applied_hardforks_view AS
SELECT
    hah.hardfork_num,
    hafd.block_id_to_num(hah.block_id) AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
CROSS JOIN hafd.hive_state hs
WHERE hah.block_id <= hs.consistent_block
  AND NOT EXISTS (
      SELECT 1 FROM hafd.blocks hb2
      WHERE hb2.block_id > hah.block_id
        AND hb2.block_id < (((hah.block_id >> 32) + 1) << 32)
        AND hb2.block_id <= hs.consistent_block
  );
