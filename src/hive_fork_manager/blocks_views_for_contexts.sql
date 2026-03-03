-- =============================================================================
-- View Creation Functions for HAF Contexts
-- =============================================================================
-- These functions create views that present data for specific application contexts.
--
-- PERFORMANCE STRATEGY:
-- blocks_view_internal uses PK-range NOT EXISTS for fork deduplication:
--   WHERE hb2.block_id > hb.block_id AND hb2.block_id < (((hb.block_id >> 32) + 1) << 32)
-- This gives Index Only Scan on pk_hive_blocks instead of Hash Anti Join.
--
-- operations_view and transactions_view use direct scans (no JOIN with
-- blocks_view_internal) to leverage existing functional indexes:
--   - operations: hive_operations_block_num_trx_in_block_idx on operation_id_to_block_num(id)
--   - transactions: hive_transactions_block_id_to_num_idx on block_id_to_num(block_id)
-- When app queries add constant block_num range bounds (e.g. BETWEEN X AND Y),
-- PostgreSQL pushes them as Index Cond on these functional indexes.
--
-- Other data views (account_operations, accounts, signatures, applied_hardforks,
-- operations_view_extended) keep JOIN with blocks_view_internal since they either
-- lack suitable functional indexes or need columns from the blocks table.
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.create_context_data_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.context_data_view AS
        SELECT
        hc.current_block_num,
        hc.irreversible_block,
        hc.fork_id,
        LEAST(
              hc.irreversible_block
            , hc.current_block_num
        ) AS min_block,
        hc.current_block_num > hc.irreversible_block AND hc.is_forking AS reversible_range
        FROM hafd.contexts hc
        WHERE hc.name::text = ''%s''::text
        limit 1
        ;', __schema, _context_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_context_data_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
EXECUTE format( 'DROP VIEW IF EXISTS %s.context_data_view CASCADE;', __schema );
END;
$BODY$
;

--- Function required to preserve valid ownership (the role being an owner of app-context) when view has been rebuilt
--- because of automatic detach process (while performing maintenance actions where different database role is used)
CREATE OR REPLACE FUNCTION hive.adjust_view_ownership( _context_name TEXT, _view_base_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
  __owner_name NAME;
  __schema TEXT;
BEGIN
  SELECT c.owner, c.schema INTO __owner_name, __schema FROM hafd.contexts c WHERE c.name = _context_name;

  EXECUTE format('ALTER VIEW %s.%s OWNER TO %s;', __schema, _view_base_name, __owner_name);

END;
$BODY$
;

-- =============================================================================
-- blocks_view - Uses block_id from blocks table
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.create_blocks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    IF __is_forking THEN
        -- Forking context: select canonical block per block_num using NOT EXISTS
        -- Visibility rules:
        --   - Irreversible (block_num <= irreversible_block): from any fork <= consistent_block's fork_id
        --   - Reversible (block_num > irreversible_block): from any fork <= context's fork_id
        -- For each block_num, pick highest block_id among visible blocks
        -- Uses PK-range NOT EXISTS on pk_hive_blocks for efficient dedup:
        --   NOT EXISTS (SELECT 1 FROM hafd.blocks hb2
        --               WHERE hb2.block_id > row.block_id
        --                 AND hb2.block_id < (((row.block_id >> 32) + 1) << 32)
        --                 AND (fork visibility conditions))
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.blocks_view_internal AS
            SELECT
                hafd.block_id_to_num(hb.block_id) AS num,
                hb.block_id,
                hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
                hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
                hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
                hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
                hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
            FROM hafd.blocks hb, %s.context_data_view c, hafd.hive_state hs
            WHERE hafd.block_id_to_num(hb.block_id) <= c.current_block_num
              AND (
                  (hafd.block_id_to_num(hb.block_id) <= c.irreversible_block
                   AND hafd.block_id_to_fork(hb.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0))
                  OR
                  (hafd.block_id_to_num(hb.block_id) > c.irreversible_block
                   AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
              )
              AND (
                  NOT EXISTS (SELECT 1 FROM hafd.block_conflicts LIMIT 1)
                  OR NOT EXISTS (
                      SELECT 1 FROM hafd.blocks hb2
                      WHERE hb2.block_id > hb.block_id
                        AND hb2.block_id < (((hb.block_id >> 32) + 1) << 32)
                        AND (
                            (hafd.block_id_to_num(hb.block_id) <= c.irreversible_block
                             AND hafd.block_id_to_fork(hb2.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0))
                            OR
                            (hafd.block_id_to_num(hb.block_id) > c.irreversible_block
                             AND hafd.block_id_to_fork(hb2.block_id) <= c.fork_id)
                        )
                  )
              )
            ;
            CREATE OR REPLACE VIEW %s.blocks_view AS
            SELECT num, hash, prev, created_at, producer_account_id,
                   transaction_merkle_root, extensions, witness_signature,
                   signing_key, hbd_interest_rate, total_vesting_fund_hive,
                   total_vesting_shares, total_reward_fund_hive, virtual_supply,
                   current_supply, current_hbd_supply, dhf_interval_ledger
            FROM %s.blocks_view_internal;
            ', __schema, __schema, __schema, __schema
        );
    ELSE
        -- Non-forking context: fork visibility filter ensures only blocks from
        -- valid forks are visible. No NOT EXISTS dedup needed because irreversible
        -- blocks have at most one version per (block_num, fork_id) visible.
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.blocks_view_internal AS
            SELECT
                hafd.block_id_to_num(hb.block_id) AS num,
                hb.block_id,
                hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
                hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
                hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
                hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
                hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
            FROM hafd.blocks hb, hafd.hive_state hs
            WHERE hafd.block_id_to_num(hb.block_id) <= (SELECT c.min_block FROM %s.context_data_view c)
              AND hafd.block_id_to_fork(hb.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0)
            ;
            CREATE OR REPLACE VIEW %s.blocks_view AS
            SELECT num, hash, prev, created_at, producer_account_id,
                   transaction_merkle_root, extensions, witness_signature,
                   signing_key, hbd_interest_rate, total_vesting_fund_hive,
                   total_vesting_shares, total_reward_fund_hive, virtual_supply,
                   current_supply, current_hbd_supply, dhf_interval_ledger
            FROM %s.blocks_view_internal;
            ', __schema, __schema, __schema, __schema
        );
    END IF;

    PERFORM hive.adjust_view_ownership(_context_name, 'blocks_view');
    PERFORM hive.adjust_view_ownership(_context_name, 'blocks_view_internal');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_blocks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    -- All irreversible: canonical block selection
    -- Uses c.min_block (not c.irreversible_block) as upper bound because during
    -- massive sync, irreversible_block is the chain head while min_block is the
    -- current batch position. Scanning up to irreversible_block would scan the
    -- entire blocks table instead of just the current batch slice.
    -- All irreversible: fork visibility filter only, no NOT EXISTS dedup needed.
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.blocks_view_internal AS
        SELECT
            hafd.block_id_to_num(hb.block_id) AS num,
            hb.block_id,
            hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
            hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
            hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
            hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
            hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
        FROM hafd.blocks hb, hafd.hive_state hs
        WHERE hafd.block_id_to_num(hb.block_id) <= (SELECT c.min_block FROM %s.context_data_view c)
          AND hafd.block_id_to_fork(hb.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0)
        ;
        CREATE OR REPLACE VIEW %s.blocks_view AS
        SELECT num, hash, prev, created_at, producer_account_id,
                   transaction_merkle_root, extensions, witness_signature,
                   signing_key, hbd_interest_rate, total_vesting_fund_hive,
                   total_vesting_shares, total_reward_fund_hive, virtual_supply,
                   current_supply, current_hbd_supply, dhf_interval_ledger
        FROM %s.blocks_view_internal;
        ', __schema, __schema, __schema, __schema
    );

    PERFORM hive.adjust_view_ownership(_context_name, 'blocks_view');
    PERFORM hive.adjust_view_ownership(_context_name, 'blocks_view_internal');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_blocks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.blocks_view CASCADE; DROP VIEW IF EXISTS %s.blocks_view_internal CASCADE;', __schema, __schema );
END;
$BODY$
;

-- =============================================================================
-- transactions_view - Uses block_num from transactions table
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.create_transactions_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    IF __is_forking THEN
        -- Forking context: direct scan with inline fork visibility + PK-range dedup.
        -- Uses functional index hive_transactions_block_id_to_num_idx when the
        -- application query provides constant block_num range bounds (e.g. BETWEEN X AND Y).
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.transactions_view AS
            SELECT hafd.block_id_to_num(ht.block_id) AS block_num,
                   ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
                   ht.ref_block_prefix, ht.expiration, ht.signature
            FROM hafd.transactions ht, %s.context_data_view c, hafd.hive_state hs
            WHERE hafd.block_id_to_num(ht.block_id) <= c.current_block_num
              AND (
                  (hafd.block_id_to_num(ht.block_id) <= c.irreversible_block
                   AND hafd.block_id_to_fork(ht.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0))
                  OR
                  (hafd.block_id_to_num(ht.block_id) > c.irreversible_block
                   AND hafd.block_id_to_fork(ht.block_id) <= c.fork_id)
              )
              AND (
                  NOT EXISTS (SELECT 1 FROM hafd.block_conflicts LIMIT 1)
                  OR NOT EXISTS (
                      SELECT 1 FROM hafd.blocks hb2
                      WHERE hb2.block_id > ht.block_id
                        AND hb2.block_id < (((ht.block_id >> 32) + 1) << 32)
                        AND (
                            (hafd.block_id_to_num(ht.block_id) <= c.irreversible_block
                             AND hafd.block_id_to_fork(hb2.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0))
                            OR
                            (hafd.block_id_to_num(ht.block_id) > c.irreversible_block
                             AND hafd.block_id_to_fork(hb2.block_id) <= c.fork_id)
                        )
                  )
              )
            ;', __schema, __schema
        );
    ELSE
        -- Non-forking context: fork visibility filter only, no NOT EXISTS dedup needed.
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.transactions_view AS
            SELECT hafd.block_id_to_num(ht.block_id) AS block_num,
                   ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
                   ht.ref_block_prefix, ht.expiration, ht.signature
            FROM hafd.transactions ht, hafd.hive_state hs
            WHERE hafd.block_id_to_num(ht.block_id) <= (SELECT c.min_block FROM %s.context_data_view c)
              AND hafd.block_id_to_fork(ht.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0)
            ;', __schema, __schema
        );
    END IF;
    PERFORM hive.adjust_view_ownership(_context_name, 'transactions_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_transactions_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    -- All irreversible: fork visibility filter only, no NOT EXISTS dedup needed.
    -- Uses c.min_block (not c.irreversible_block) as upper bound because during
    -- massive sync, irreversible_block is the chain head while min_block is the
    -- current batch position.
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.transactions_view AS
        SELECT hafd.block_id_to_num(ht.block_id) AS block_num,
               ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
               ht.ref_block_prefix, ht.expiration, ht.signature
        FROM hafd.transactions ht, hafd.hive_state hs
        WHERE hafd.block_id_to_num(ht.block_id) <= (SELECT c.min_block FROM %s.context_data_view c)
          AND hafd.block_id_to_fork(ht.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0)
        ;', __schema, __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'transactions_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_transactions_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.transactions_view CASCADE;', __schema );
END;
$BODY$
;

-- =============================================================================
-- operations_view - Uses id encoding (block_num|seq|type)
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.create_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    IF __is_forking THEN
        -- Forking context: direct scan with inline fork visibility + PK-range dedup.
        -- Uses functional index hive_operations_block_num_trx_in_block_idx
        -- (on operation_id_to_block_num(id)) when the application query provides
        -- constant block_num range bounds.
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.operations_view AS
            SELECT
                ho.id,
                hafd.operation_id_to_block_num(ho.id) AS block_num,
                ho.trx_in_block, ho.op_pos,
                ho.op_type_id,
                ho.body_binary,
                ho.body_binary::jsonb AS body,
                ho.custom_json_type_id
            FROM hafd.operations ho, %s.context_data_view c, hafd.hive_state hs
            WHERE hafd.operation_id_to_block_num(ho.id) <= c.current_block_num
              AND (
                  (hafd.block_id_to_num(ho.block_id) <= c.irreversible_block
                   AND hafd.block_id_to_fork(ho.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0))
                  OR
                  (hafd.block_id_to_num(ho.block_id) > c.irreversible_block
                   AND hafd.block_id_to_fork(ho.block_id) <= c.fork_id)
              )
              AND (
                  NOT EXISTS (SELECT 1 FROM hafd.block_conflicts LIMIT 1)
                  OR NOT EXISTS (
                      SELECT 1 FROM hafd.blocks hb2
                      WHERE hb2.block_id > ho.block_id
                        AND hb2.block_id < (((ho.block_id >> 32) + 1) << 32)
                        AND (
                            (hafd.block_id_to_num(ho.block_id) <= c.irreversible_block
                             AND hafd.block_id_to_fork(hb2.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0))
                            OR
                            (hafd.block_id_to_num(ho.block_id) > c.irreversible_block
                             AND hafd.block_id_to_fork(hb2.block_id) <= c.fork_id)
                        )
                  )
              )
            ;', __schema, __schema
        );
    ELSE
        -- Non-forking context: fork visibility filter only, no NOT EXISTS dedup needed.
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.operations_view AS
            SELECT
                ho.id,
                hafd.operation_id_to_block_num(ho.id) AS block_num,
                ho.trx_in_block, ho.op_pos,
                ho.op_type_id,
                ho.body_binary,
                ho.body_binary::jsonb AS body,
                ho.custom_json_type_id
            FROM hafd.operations ho, hafd.hive_state hs
            WHERE hafd.operation_id_to_block_num(ho.id) <= (SELECT c.min_block FROM %s.context_data_view c)
              AND hafd.block_id_to_fork(ho.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0)
            ;', __schema, __schema
        );
    END IF;
    PERFORM hive.adjust_view_ownership(_context_name, 'operations_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_operations_view_extended( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    -- De-JOIN: use operations_view (which has its own functional-index-driven
    -- scan) and join to blocks_view_internal on block_num for the timestamp.
    -- The old approach (JOIN hafd.operations ON block_id) prevented PostgreSQL
    -- from using the operations block_num functional index for range scans,
    -- causing full table scans at the Steem bubble (445s -> 0.9s per batch).
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view_extended AS
        SELECT
            ov.id,
            ov.block_num,
            ov.trx_in_block, ov.op_pos,
            ov.op_type_id,
            b.created_at AS timestamp,
            ov.body_binary,
            ov.body,
            ov.custom_json_type_id
        FROM %s.operations_view ov
        JOIN %s.blocks_view_internal b ON b.num = ov.block_num
        ;', __schema, __schema, __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'operations_view_extended');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    -- All irreversible: fork visibility filter only, no NOT EXISTS dedup needed.
    -- Uses c.min_block (not c.irreversible_block) as upper bound because during
    -- massive sync, irreversible_block is the chain head while min_block is the
    -- current batch position. Scanning up to irreversible_block would scan the
    -- entire operations table instead of just the current batch slice.
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view AS
        SELECT
            ho.id,
            hafd.operation_id_to_block_num(ho.id) AS block_num,
            ho.trx_in_block, ho.op_pos,
            ho.op_type_id,
            ho.body_binary,
            ho.body_binary::jsonb AS body,
            ho.custom_json_type_id
        FROM hafd.operations ho, hafd.hive_state hs
        WHERE hafd.operation_id_to_block_num(ho.id) <= (SELECT c.min_block FROM %s.context_data_view c)
          AND hafd.block_id_to_fork(ho.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0)
        ;', __schema, __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'operations_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_operations_view_extended( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    -- All irreversible: de-JOIN same as forking/non-forking variant.
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view_extended AS
        SELECT
            ov.id,
            ov.block_num,
            ov.trx_in_block, ov.op_pos,
            ov.op_type_id,
            b.created_at AS timestamp,
            ov.body_binary,
            ov.body,
            ov.custom_json_type_id
        FROM %s.operations_view ov
        JOIN %s.blocks_view_internal b ON b.num = ov.block_num
        ;', __schema, __schema, __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'operations_view_extended');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.operations_view CASCADE;', __schema );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_operations_view_extended( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.operations_view_extended CASCADE;', __schema );
END;
$BODY$
;

-- =============================================================================
-- signatures_view (transactions_multisig) - Uses trx_hash reference
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.create_signatures_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    IF __is_forking THEN
        -- Forking context: join directly on block_id (transactions_multisig has block_id)
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW AS
            SELECT htm.trx_hash, htm.signature
            FROM hafd.transactions_multisig htm
            JOIN %s.blocks_view_internal b ON b.block_id = htm.block_id
            ;', __schema, __schema
        );
    ELSE
        -- Non-forking context: filter by min_block
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW AS
            SELECT htm.trx_hash, htm.signature
            FROM hafd.transactions_multisig htm
            JOIN %s.blocks_view_internal b ON b.block_id = htm.block_id
            ;', __schema, __schema
        );
    END IF;
    PERFORM hive.adjust_view_ownership(_context_name, 'TRANSACTIONS_MULTISIG_VIEW');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_signatures_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    -- All irreversible: show all signatures (join directly on block_id)
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW AS
        SELECT htm.trx_hash, htm.signature
        FROM hafd.transactions_multisig htm
        JOIN %s.blocks_view_internal b ON b.block_id = htm.block_id
        ;', __schema, __schema
    );

    PERFORM hive.adjust_view_ownership(_context_name, 'TRANSACTIONS_MULTISIG_VIEW');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_signatures_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.TRANSACTIONS_MULTISIG_VIEW CASCADE;', __schema );
END;
$BODY$
;

-- =============================================================================
-- accounts_view - Uses block_num from accounts table
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.create_accounts_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    -- Both forking and non-forking contexts use the same query:
    -- blocks_view_internal already handles the context-specific filtering
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.accounts_view AS
        SELECT ha.id, ha.name
        FROM hafd.accounts ha
        LEFT JOIN %s.blocks_view_internal b ON b.block_id = ha.block_id
        WHERE ha.block_id IS NULL OR b.block_id IS NOT NULL
        ;', __schema, __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'accounts_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_accounts_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    -- All irreversible: show all accounts
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.accounts_view AS
        SELECT ha.id, ha.name
        FROM hafd.accounts ha
        LEFT JOIN %s.blocks_view_internal b ON b.block_id = ha.block_id
        WHERE ha.block_id IS NULL OR b.block_id IS NOT NULL
        ;', __schema, __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'accounts_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_accounts_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.accounts_view CASCADE;', __schema );
END;
$BODY$
;

-- =============================================================================
-- account_operations_view - Uses operation_id encoding
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.create_account_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    IF __is_forking THEN
        -- Forking context: filter by context block range
        -- operation_id is stored directly in account_operations (no JOIN needed)
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.account_operations_view AS
            SELECT
                b.num AS block_num,
                hao.account_id, hao.transacting_account_id, hao.account_op_seq_no,
                hao.operation_id,
                hao.op_type_id
            FROM hafd.account_operations hao
            JOIN %s.blocks_view_internal b ON b.block_id = hao.block_id
            ;', __schema, __schema
        );
    ELSE
        -- Non-forking context: filter by min_block
        -- operation_id is stored directly in account_operations (no JOIN needed)
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.account_operations_view AS
            SELECT
                b.num AS block_num,
                hao.account_id, hao.transacting_account_id, hao.account_op_seq_no,
                hao.operation_id,
                hao.op_type_id
            FROM hafd.account_operations hao
            JOIN %s.blocks_view_internal b ON b.block_id = hao.block_id
            ;', __schema, __schema
        );
    END IF;
    PERFORM hive.adjust_view_ownership(_context_name, 'account_operations_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_account_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    -- All irreversible: show all account operations
    -- operation_id is stored directly in account_operations (no JOIN needed)
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.account_operations_view AS
        SELECT
            b.num AS block_num,
            hao.account_id, hao.transacting_account_id, hao.account_op_seq_no,
            hao.operation_id,
            hao.op_type_id
        FROM hafd.account_operations hao
        JOIN %s.blocks_view_internal b ON b.block_id = hao.block_id
        ;', __schema, __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'account_operations_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_account_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.account_operations_view CASCADE;', __schema );
END;
$BODY$
;

-- =============================================================================
-- applied_hardforks_view - Uses block_num from applied_hardforks table
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.create_applied_hardforks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    IF __is_forking THEN
        -- Forking context: filter by context block range
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
            SELECT hah.hardfork_num, b.num AS block_num, hah.hardfork_vop_id
            FROM hafd.applied_hardforks hah
            JOIN %s.blocks_view_internal b ON b.block_id = hah.block_id
            ;', __schema, __schema
        );
    ELSE
        -- Non-forking context: filter by min_block
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
            SELECT hah.hardfork_num, b.num AS block_num, hah.hardfork_vop_id
            FROM hafd.applied_hardforks hah
            JOIN %s.blocks_view_internal b ON b.block_id = hah.block_id
            ;', __schema, __schema
        );
    END IF;
    PERFORM hive.adjust_view_ownership(_context_name, 'applied_hardforks_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_all_irreversible_applied_hardforks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    -- All irreversible: show all applied hardforks
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
        SELECT hah.hardfork_num, b.num AS block_num, hah.hardfork_vop_id
        FROM hafd.applied_hardforks hah
        JOIN %s.blocks_view_internal b ON b.block_id = hah.block_id
        ;', __schema, __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'applied_hardforks_view');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_applied_hardforks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __schema TEXT;
BEGIN
    SELECT hc.schema INTO __schema
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;
    EXECUTE format( 'DROP VIEW IF EXISTS %s.applied_hardforks_view;', __schema );
END;
$BODY$
;
