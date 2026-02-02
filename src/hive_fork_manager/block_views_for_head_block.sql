-- =============================================================================
-- Head Block Views for hive schema
-- =============================================================================
-- These views show all data including reversible blocks.
-- Canonical block selection: For each grouping key, select the row with the
-- highest block_id (newest fork version).
--
-- Pattern used: Scalar subquery with ORDER BY block_id DESC LIMIT 1
-- - Efficiently uses indexes to find canonical version
-- - Works correctly regardless of how many fork versions exist
-- - Enables predicate pushdown for WHERE clauses
--
-- With the hybrid schema:
--   - blocks: uses block_id (for fork tracking)
--   - transactions: uses block_id (for fork tracking)
--   - operations: uses id (encoded block_num|seq|type) + block_id
--   - account_operations: uses block_id
--   - accounts: uses block_id (NULL for initial dump)
--   - applied_hardforks: uses block_id
-- =============================================================================

-- =============================================================================
-- blocks_view - Canonical blocks with conflict-based optimization
-- =============================================================================
-- For each block_num, returns the version with highest block_id.
-- OPTIMIZATION: When block_conflicts is empty (normal operation), returns all
-- rows directly without canonical selection overhead.
CREATE OR REPLACE VIEW hive.blocks_view AS
SELECT
    hafd.block_id_to_num(hb.block_id) AS num,
    hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
    hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
    hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
    hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
    hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
FROM hafd.blocks hb
WHERE
    NOT EXISTS (SELECT 1 FROM hafd.block_conflicts LIMIT 1)
    OR
    (
        NOT EXISTS (
            SELECT 1 FROM hafd.block_conflicts bc
            WHERE bc.block_num = hafd.block_id_to_num(hb.block_id)
        )
        OR
        hb.block_id = (
            SELECT hb2.block_id
            FROM hafd.blocks hb2
            WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(hb.block_id)
            ORDER BY hb2.block_id DESC
            LIMIT 1
        )
    );

-- =============================================================================
-- transactions_view - Canonical transactions with conflict-based optimization
-- =============================================================================
-- For each (block_num, trx_in_block), returns the version with highest block_id.
-- OPTIMIZATION: When block_conflicts is empty (normal operation), returns all
-- rows directly without canonical selection overhead.
CREATE OR REPLACE VIEW hive.transactions_view AS
SELECT
    hafd.block_id_to_num(ht.block_id) AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
WHERE
    NOT EXISTS (SELECT 1 FROM hafd.block_conflicts LIMIT 1)
    OR
    (
        NOT EXISTS (
            SELECT 1 FROM hafd.block_conflicts bc
            WHERE bc.block_num = hafd.block_id_to_num(ht.block_id)
        )
        OR
        ht.block_id = (
            SELECT ht2.block_id
            FROM hafd.transactions ht2
            WHERE hafd.block_id_to_num(ht2.block_id) = hafd.block_id_to_num(ht.block_id)
              AND ht2.trx_in_block = ht.trx_in_block
            ORDER BY ht2.block_id DESC
            LIMIT 1
        )
    );

-- =============================================================================
-- operations_view - Canonical operations with conflict-based optimization
-- =============================================================================
-- For each (block_num, seq_in_block), returns the version with highest block_id.
-- OPTIMIZATION: When block_conflicts is empty (normal operation), returns all
-- rows directly without canonical selection overhead.
CREATE OR REPLACE VIEW hive.operations_view AS
SELECT
    ho.id,
    hafd.operation_id_to_block_num(ho.id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    hafd.operation_id_to_type_id(ho.id) AS op_type_id,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
WHERE
    NOT EXISTS (SELECT 1 FROM hafd.block_conflicts LIMIT 1)
    OR
    (
        NOT EXISTS (
            SELECT 1 FROM hafd.block_conflicts bc
            WHERE bc.block_num = hafd.operation_id_to_block_num(ho.id)
        )
        OR
        ho.block_id = (
            SELECT ho2.block_id
            FROM hafd.operations ho2
            WHERE (ho2.id >> 8) = (ho.id >> 8)
            ORDER BY ho2.block_id DESC
            LIMIT 1
        )
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
    ov.body
FROM hive.operations_view ov
JOIN hive.blocks_view b ON b.num = ov.block_num;

-- =============================================================================
-- account_operations_view - Account operations with stored operation_id
-- =============================================================================
-- Uses stored operation_id to avoid JOIN with operations table.
-- This is critical for get_account_history performance (enables LIMIT pushdown).
-- OPTIMIZATION: When block_conflicts is empty, skips canonical selection entirely.
CREATE OR REPLACE VIEW hive.account_operations_view AS
SELECT
    hafd.block_id_to_num(hao.block_id) AS block_num,
    hao.account_id,
    hao.transacting_account_id,
    hao.account_op_seq_no,
    hao.operation_id,
    hafd.operation_id_to_type_id(hao.operation_id) AS op_type_id
FROM hafd.account_operations hao
WHERE
    -- Fast path: no conflicts exist, return all rows directly
    NOT EXISTS (SELECT 1 FROM hafd.block_conflicts LIMIT 1)
    OR
    -- Block has no conflict, return directly
    NOT EXISTS (
        SELECT 1 FROM hafd.block_conflicts bc
        WHERE bc.block_num = hafd.block_id_to_num(hao.block_id)
    )
    OR
    -- Block has conflict, select canonical version (highest block_id for this account_op)
    hao.block_id = (
        SELECT hao2.block_id
        FROM hafd.account_operations hao2
        WHERE hao2.account_id = hao.account_id
          AND hao2.account_op_seq_no = hao.account_op_seq_no
        ORDER BY hao2.block_id DESC
        LIMIT 1
    );

-- =============================================================================
-- accounts_view - Accounts with conflict-based optimization
-- =============================================================================
-- Shows accounts from canonical blocks or initial dump.
-- OPTIMIZATION: When block_conflicts is empty (normal operation), returns all
-- rows directly without canonical selection overhead.
CREATE OR REPLACE VIEW hive.accounts_view AS
SELECT ha.id, ha.name
FROM hafd.accounts ha
WHERE
    -- Global fast path: if no conflicts exist at all
    NOT EXISTS (SELECT 1 FROM hafd.block_conflicts LIMIT 1)
    OR
    (
        -- Account from initial dump (NULL block_id)
        ha.block_id IS NULL
        AND NOT EXISTS (
            SELECT 1 FROM hafd.accounts ha2
            WHERE ha2.id = ha.id AND ha2.block_id IS NOT NULL
        )
    )
    OR
    (
        -- Account from non-conflicted block
        ha.block_id IS NOT NULL
        AND NOT EXISTS (
            SELECT 1 FROM hafd.block_conflicts bc
            WHERE bc.block_num = hafd.block_id_to_num(ha.block_id)
        )
    )
    OR
    (
        -- Slow path: conflict exists, use full canonical selection
        ha.block_id IS NOT NULL
        AND ha.block_id = (
            SELECT hb.block_id
            FROM hafd.blocks hb
            WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(ha.block_id)
            ORDER BY hb.block_id DESC
            LIMIT 1
        )
        AND ha.block_id = (
            SELECT ha2.block_id
            FROM hafd.accounts ha2
            WHERE ha2.id = ha.id
              AND ha2.block_id IS NOT NULL
              AND ha2.block_id = (
                  SELECT hb.block_id
                  FROM hafd.blocks hb
                  WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(ha2.block_id)
                  ORDER BY hb.block_id DESC
                  LIMIT 1
              )
            ORDER BY ha2.block_id DESC
            LIMIT 1
        )
    );

-- =============================================================================
-- transactions_multisig_view - Multisig signatures with conflict-based optimization
-- =============================================================================
-- Shows multisig signatures only from canonical blocks.
-- OPTIMIZATION: Uses block_conflicts table to skip canonical selection for
-- non-conflicted blocks.
CREATE OR REPLACE VIEW hive.transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
WHERE (
    -- Fast path: no conflict for this block_num
    NOT EXISTS (
        SELECT 1 FROM hafd.block_conflicts bc
        WHERE bc.block_num = hafd.block_id_to_num(htm.block_id)
    )
)
OR (
    -- Slow path: conflict exists, use canonical selection
    htm.block_id = (
        SELECT hb.block_id
        FROM hafd.blocks hb
        WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(htm.block_id)
        ORDER BY hb.block_id DESC
        LIMIT 1
    )
);

-- =============================================================================
-- applied_hardforks_view - Canonical hardforks with conflict-based optimization
-- =============================================================================
CREATE OR REPLACE VIEW hive.applied_hardforks_view AS
SELECT
    hah.hardfork_num,
    hafd.block_id_to_num(hah.block_id) AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
WHERE (
    -- Fast path: no conflict for this block_num
    NOT EXISTS (
        SELECT 1 FROM hafd.block_conflicts bc
        WHERE bc.block_num = hafd.block_id_to_num(hah.block_id)
    )
)
OR (
    -- Slow path: conflict exists, use canonical selection
    hah.block_id = (
        SELECT hah2.block_id
        FROM hafd.applied_hardforks hah2
        WHERE hah2.hardfork_num = hah.hardfork_num
        ORDER BY hah2.block_id DESC
        LIMIT 1
    )
);

-- =============================================================================
-- Irreversible views - Only show data from irreversible blocks
-- =============================================================================
-- These views filter to blocks at or below consistent_block (irreversible).
-- Uses NOT EXISTS to check for higher block_id versions within irreversible range.

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
WHERE hafd.block_id_to_num(hb.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hb.block_id = (
      SELECT hb2.block_id
      FROM hafd.blocks hb2
      WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(hb.block_id)
        AND hafd.block_id_to_num(hb2.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      ORDER BY hb2.block_id DESC
      LIMIT 1
  );

CREATE OR REPLACE VIEW hive.irreversible_transactions_view AS
SELECT
    hafd.block_id_to_num(ht.block_id) AS block_num,
    ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
    ht.ref_block_prefix, ht.expiration, ht.signature
FROM hafd.transactions ht
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(ht.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND ht.block_id = (
      SELECT ht2.block_id
      FROM hafd.transactions ht2
      WHERE hafd.block_id_to_num(ht2.block_id) = hafd.block_id_to_num(ht.block_id)
        AND ht2.trx_in_block = ht.trx_in_block
        AND hafd.block_id_to_num(ht2.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      ORDER BY ht2.block_id DESC
      LIMIT 1
  );

CREATE OR REPLACE VIEW hive.irreversible_operations_view AS
SELECT
    ho.id,
    hafd.operation_id_to_block_num(ho.id) AS block_num,
    ho.trx_in_block,
    ho.op_pos,
    hafd.operation_id_to_type_id(ho.id) AS op_type_id,
    ho.body_binary,
    ho.body_binary::jsonb AS body
FROM hafd.operations ho
CROSS JOIN hafd.hive_state hs
WHERE hafd.operation_id_to_block_num(ho.id) <= hafd.block_id_to_num(hs.consistent_block)
  AND ho.block_id = (
      SELECT ho2.block_id
      FROM hafd.operations ho2
      WHERE (ho2.id >> 8) = (ho.id >> 8)
        AND hafd.operation_id_to_block_num(ho2.id) <= hafd.block_id_to_num(hs.consistent_block)
      ORDER BY ho2.block_id DESC
      LIMIT 1
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
    ov.body
FROM hive.irreversible_operations_view ov
JOIN hive.irreversible_blocks_view hb ON hb.num = ov.block_num;

CREATE OR REPLACE VIEW hive.irreversible_account_operations_view AS
SELECT
    hafd.block_id_to_num(hao.block_id) AS block_num,
    hao.account_id,
    hao.transacting_account_id,
    hao.account_op_seq_no,
    hao.operation_id,
    hafd.operation_id_to_type_id(hao.operation_id) AS op_type_id
FROM hafd.account_operations hao
CROSS JOIN hafd.hive_state hs
WHERE hao.block_id = (
    SELECT hao2.block_id
    FROM hafd.account_operations hao2
    WHERE hao2.account_id = hao.account_id
      AND hao2.account_op_seq_no = hao.account_op_seq_no
      AND hao2.block_id <= hs.consistent_block
    ORDER BY hao2.block_id DESC
    LIMIT 1
);

CREATE OR REPLACE VIEW hive.irreversible_accounts_view AS
SELECT ha.id, ha.name
FROM hafd.accounts ha
CROSS JOIN hafd.hive_state hs
WHERE (
    -- Account is from initial dump AND no version from irreversible canonical blocks exists
    ha.block_id IS NULL
    AND NOT EXISTS (
        SELECT 1 FROM hafd.accounts ha2
        WHERE ha2.id = ha.id
          AND ha2.block_id IS NOT NULL
          AND ha2.block_id <= hs.consistent_block
          AND ha2.block_id = (
              SELECT hb.block_id
              FROM hafd.blocks hb
              WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(ha2.block_id)
                AND hb.block_id <= hs.consistent_block
              ORDER BY hb.block_id DESC
              LIMIT 1
          )
    )
)
OR (
    -- Account is from an irreversible canonical block AND is the latest version
    ha.block_id IS NOT NULL
    AND ha.block_id <= hs.consistent_block
    AND ha.block_id = (
        SELECT hb.block_id
        FROM hafd.blocks hb
        WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(ha.block_id)
          AND hb.block_id <= hs.consistent_block
        ORDER BY hb.block_id DESC
        LIMIT 1
    )
    AND ha.block_id = (
        SELECT ha2.block_id
        FROM hafd.accounts ha2
        WHERE ha2.id = ha.id
          AND ha2.block_id IS NOT NULL
          AND ha2.block_id <= hs.consistent_block
          AND ha2.block_id = (
              SELECT hb.block_id
              FROM hafd.blocks hb
              WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(ha2.block_id)
                AND hb.block_id <= hs.consistent_block
              ORDER BY hb.block_id DESC
              LIMIT 1
          )
        ORDER BY ha2.block_id DESC
        LIMIT 1
    )
);

CREATE OR REPLACE VIEW hive.irreversible_transactions_multisig_view AS
SELECT htm.trx_hash, htm.signature
FROM hafd.transactions_multisig htm
CROSS JOIN hafd.hive_state hs
WHERE htm.block_id <= hs.consistent_block
  AND htm.block_id = (
      SELECT hb.block_id
      FROM hafd.blocks hb
      WHERE hafd.block_id_to_num(hb.block_id) = hafd.block_id_to_num(htm.block_id)
        AND hb.block_id <= hs.consistent_block
      ORDER BY hb.block_id DESC
      LIMIT 1
  );

CREATE OR REPLACE VIEW hive.irreversible_applied_hardforks_view AS
SELECT
    hah.hardfork_num,
    hafd.block_id_to_num(hah.block_id) AS block_num,
    hah.hardfork_vop_id
FROM hafd.applied_hardforks hah
CROSS JOIN hafd.hive_state hs
WHERE hafd.block_id_to_num(hah.block_id) <= hafd.block_id_to_num(hs.consistent_block)
  AND hah.block_id = (
      SELECT hah2.block_id
      FROM hafd.applied_hardforks hah2
      WHERE hah2.hardfork_num = hah.hardfork_num
        AND hafd.block_id_to_num(hah2.block_id) <= hafd.block_id_to_num(hs.consistent_block)
      ORDER BY hah2.block_id DESC
      LIMIT 1
  );
