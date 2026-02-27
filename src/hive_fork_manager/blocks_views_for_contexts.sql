-- =============================================================================
-- View Creation Functions for HAF Contexts
-- =============================================================================
-- These functions create views that present data for specific application contexts.
-- With the hybrid schema:
--   - blocks: uses block_id (for fork tracking)
--   - transactions: uses block_num (original compact format)
--   - operations: uses id (encoded block_num|seq|type)
--   - account_operations: uses operation_id
--   - accounts: uses block_num
--   - applied_hardforks: uses block_num
--
-- Data views (transactions, operations, etc.) embed a CTE-gated blocks lookup
-- directly instead of joining blocks_view_internal. This allows PostgreSQL to:
-- 1. Push block_num range filters into the blocks index scan
-- 2. Use pk_hive_operations (and similar PKs) for nested loop joins
-- 3. Use DISTINCT ON for canonical block selection (single-pass sort vs per-row anti-join)
--
-- hive_state optimization: The max allowed fork_id from hive_state is
-- pre-computed once in a MATERIALIZED CTE (hs_data) instead of joining
-- hafd.hive_state as a table in both the visible_blocks and anti-join
-- subqueries. This halves cost estimates and simplifies the plan.
--
-- Canonical block selection: Uses DISTINCT ON (block_num) ORDER BY block_id DESC
-- to pick the highest block_id per block_num in a single sort pass, replacing
-- the previous NOT EXISTS anti-join which required per-row index probes.
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
        -- Forking context: select canonical block per block_num using DISTINCT ON
        -- Visibility rules:
        --   - Irreversible (block_num <= irreversible_block): from any fork <= consistent_block's fork_id
        --   - Reversible (block_num > irreversible_block): from any fork <= context's fork_id
        -- For each block_num, pick highest block_id among visible blocks
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.blocks_view_internal AS
            SELECT DISTINCT ON (hb.block_num)
                hb.block_num AS num,
                hb.block_id,
                hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
                hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
                hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
                hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
                hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
            FROM hafd.blocks hb, %s.context_data_view c,
                 LATERAL (SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0) AS max_fork FROM hafd.hive_state LIMIT 1) hs
            WHERE hb.block_num <= c.current_block_num
              AND (
                  (hb.block_num <= c.irreversible_block
                   AND hafd.block_id_to_fork(hb.block_id) <= hs.max_fork)
                  OR
                  (hb.block_num > c.irreversible_block
                   AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
              )
            ORDER BY hb.block_num, hb.block_id DESC
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
        -- Non-forking context: show blocks up to min_block using DISTINCT ON
        -- Uses same fork visibility rule as forking contexts for irreversible:
        --   fork_id <= consistent_block's fork_id
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.blocks_view_internal AS
            SELECT DISTINCT ON (hb.block_num)
                hb.block_num AS num,
                hb.block_id,
                hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
                hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
                hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
                hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
                hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
            FROM hafd.blocks hb, %s.context_data_view c,
                 LATERAL (SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0) AS max_fork FROM hafd.hive_state LIMIT 1) hs
            WHERE hb.block_num <= c.min_block
              AND hafd.block_id_to_fork(hb.block_id) <= hs.max_fork
            ORDER BY hb.block_num, hb.block_id DESC
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

    -- All irreversible: canonical block selection using DISTINCT ON
    -- Uses fork visibility rule: fork_id <= consistent_block's fork_id
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.blocks_view_internal AS
        SELECT DISTINCT ON (hb.block_num)
            hb.block_num AS num,
            hb.block_id,
            hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
            hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
            hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
            hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
            hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
        FROM hafd.blocks hb, %s.context_data_view c,
             LATERAL (SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0) AS max_fork FROM hafd.hive_state LIMIT 1) hs
        WHERE hb.block_num <= c.irreversible_block
          AND hafd.block_id_to_fork(hb.block_id) <= hs.max_fork
        ORDER BY hb.block_num, hb.block_id DESC
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
-- transactions_view - Uses block_id from transactions table
-- CTE-gated: embeds blocks lookup with DISTINCT ON dedup directly
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
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.transactions_view AS
            WITH hs_data AS MATERIALIZED (
                SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
                FROM hafd.hive_state
            ),
            visible_blocks AS (
                SELECT DISTINCT ON (hb.block_num)
                    hb.block_id, hb.block_num AS num
                FROM hafd.blocks hb, %s.context_data_view c, hs_data
                WHERE hb.block_num <= c.current_block_num
                  AND (
                      (hb.block_num <= c.irreversible_block
                       AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork)
                      OR
                      (hb.block_num > c.irreversible_block
                       AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
                  )
                ORDER BY hb.block_num, hb.block_id DESC
            )
            SELECT vb.num AS block_num, ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
                   ht.ref_block_prefix, ht.expiration, ht.signature
            FROM visible_blocks vb
            JOIN hafd.transactions ht ON ht.block_id = vb.block_id
            ;', __schema, __schema
        );
    ELSE
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.transactions_view AS
            WITH hs_data AS MATERIALIZED (
                SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
                FROM hafd.hive_state
            ),
            visible_blocks AS (
                SELECT DISTINCT ON (hb.block_num)
                    hb.block_id, hb.block_num AS num
                FROM hafd.blocks hb, %s.context_data_view c, hs_data
                WHERE hb.block_num <= c.min_block
                  AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork
                ORDER BY hb.block_num, hb.block_id DESC
            )
            SELECT vb.num AS block_num, ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
                   ht.ref_block_prefix, ht.expiration, ht.signature
            FROM visible_blocks vb
            JOIN hafd.transactions ht ON ht.block_id = vb.block_id
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

    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.transactions_view AS
        WITH hs_data AS MATERIALIZED (
            SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
            FROM hafd.hive_state
        ),
        visible_blocks AS (
            SELECT DISTINCT ON (hb.block_num)
                hb.block_id, hb.block_num AS num
            FROM hafd.blocks hb, %s.context_data_view c, hs_data
            WHERE hb.block_num <= c.irreversible_block
              AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork
            ORDER BY hb.block_num, hb.block_id DESC
        )
        SELECT vb.num AS block_num, ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
               ht.ref_block_prefix, ht.expiration, ht.signature
        FROM visible_blocks vb
        JOIN hafd.transactions ht ON ht.block_id = vb.block_id
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
-- CTE-gated: embeds blocks lookup with DISTINCT ON dedup directly
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
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.operations_view AS
            WITH hs_data AS MATERIALIZED (
                SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
                FROM hafd.hive_state
            ),
            visible_blocks AS (
                SELECT DISTINCT ON (hb.block_num)
                    hb.block_id, hb.block_num AS num
                FROM hafd.blocks hb, %s.context_data_view c, hs_data
                WHERE hb.block_num <= c.current_block_num
                  AND (
                      (hb.block_num <= c.irreversible_block
                       AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork)
                      OR
                      (hb.block_num > c.irreversible_block
                       AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
                  )
                ORDER BY hb.block_num, hb.block_id DESC
            )
            SELECT
                ho.id,
                vb.num AS block_num,
                ho.trx_in_block, ho.op_pos,
                ho.op_type_id,
                ho.body_binary,
                ho.body_binary::jsonb AS body,
                ho.custom_json_type_id
            FROM visible_blocks vb
            JOIN hafd.operations ho ON ho.block_id = vb.block_id
            ;', __schema, __schema
        );
    ELSE
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.operations_view AS
            WITH hs_data AS MATERIALIZED (
                SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
                FROM hafd.hive_state
            ),
            visible_blocks AS (
                SELECT DISTINCT ON (hb.block_num)
                    hb.block_id, hb.block_num AS num
                FROM hafd.blocks hb, %s.context_data_view c, hs_data
                WHERE hb.block_num <= c.min_block
                  AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork
                ORDER BY hb.block_num, hb.block_id DESC
            )
            SELECT
                ho.id,
                vb.num AS block_num,
                ho.trx_in_block, ho.op_pos,
                ho.op_type_id,
                ho.body_binary,
                ho.body_binary::jsonb AS body,
                ho.custom_json_type_id
            FROM visible_blocks vb
            JOIN hafd.operations ho ON ho.block_id = vb.block_id
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

    IF __is_forking THEN
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.operations_view_extended AS
            WITH hs_data AS MATERIALIZED (
                SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
                FROM hafd.hive_state
            ),
            visible_blocks AS (
                SELECT DISTINCT ON (hb.block_num)
                    hb.block_id, hb.block_num AS num, hb.created_at
                FROM hafd.blocks hb, %s.context_data_view c, hs_data
                WHERE hb.block_num <= c.current_block_num
                  AND (
                      (hb.block_num <= c.irreversible_block
                       AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork)
                      OR
                      (hb.block_num > c.irreversible_block
                       AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
                  )
                ORDER BY hb.block_num, hb.block_id DESC
            )
            SELECT
                ho.id,
                vb.num AS block_num,
                ho.trx_in_block, ho.op_pos,
                ho.op_type_id,
                vb.created_at AS timestamp,
                ho.body_binary,
                ho.body_binary::jsonb AS body,
                ho.custom_json_type_id
            FROM visible_blocks vb
            JOIN hafd.operations ho ON ho.block_id = vb.block_id
            ;', __schema, __schema
        );
    ELSE
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.operations_view_extended AS
            WITH hs_data AS MATERIALIZED (
                SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
                FROM hafd.hive_state
            ),
            visible_blocks AS (
                SELECT DISTINCT ON (hb.block_num)
                    hb.block_id, hb.block_num AS num, hb.created_at
                FROM hafd.blocks hb, %s.context_data_view c, hs_data
                WHERE hb.block_num <= c.min_block
                  AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork
                ORDER BY hb.block_num, hb.block_id DESC
            )
            SELECT
                ho.id,
                vb.num AS block_num,
                ho.trx_in_block, ho.op_pos,
                ho.op_type_id,
                vb.created_at AS timestamp,
                ho.body_binary,
                ho.body_binary::jsonb AS body,
                ho.custom_json_type_id
            FROM visible_blocks vb
            JOIN hafd.operations ho ON ho.block_id = vb.block_id
            ;', __schema, __schema
        );
    END IF;
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

    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view AS
        WITH hs_data AS MATERIALIZED (
            SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
            FROM hafd.hive_state
        ),
        visible_blocks AS (
            SELECT DISTINCT ON (hb.block_num)
                hb.block_id, hb.block_num AS num
            FROM hafd.blocks hb, %s.context_data_view c, hs_data
            WHERE hb.block_num <= c.irreversible_block
              AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork
            ORDER BY hb.block_num, hb.block_id DESC
        )
        SELECT
            ho.id,
            vb.num AS block_num,
            ho.trx_in_block, ho.op_pos,
            ho.op_type_id,
            ho.body_binary,
            ho.body_binary::jsonb AS body,
            ho.custom_json_type_id
        FROM visible_blocks vb
        JOIN hafd.operations ho ON ho.block_id = vb.block_id
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

    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view_extended AS
        WITH hs_data AS MATERIALIZED (
            SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
            FROM hafd.hive_state
        ),
        visible_blocks AS (
            SELECT DISTINCT ON (hb.block_num)
                hb.block_id, hb.block_num AS num, hb.created_at
            FROM hafd.blocks hb, %s.context_data_view c, hs_data
            WHERE hb.block_num <= c.irreversible_block
              AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork
            ORDER BY hb.block_num, hb.block_id DESC
        )
        SELECT
            ho.id,
            vb.num AS block_num,
            ho.trx_in_block, ho.op_pos,
            ho.op_type_id,
            vb.created_at AS timestamp,
            ho.body_binary,
            ho.body_binary::jsonb AS body,
            ho.custom_json_type_id
        FROM visible_blocks vb
        JOIN hafd.operations ho ON ho.block_id = vb.block_id
        ;', __schema, __schema
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
-- CTE-gated: embeds blocks lookup with DISTINCT ON dedup directly
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
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW AS
            WITH hs_data AS MATERIALIZED (
                SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
                FROM hafd.hive_state
            ),
            visible_blocks AS (
                SELECT DISTINCT ON (hb.block_num)
                    hb.block_id
                FROM hafd.blocks hb, %s.context_data_view c, hs_data
                WHERE hb.block_num <= c.current_block_num
                  AND (
                      (hb.block_num <= c.irreversible_block
                       AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork)
                      OR
                      (hb.block_num > c.irreversible_block
                       AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
                  )
                ORDER BY hb.block_num, hb.block_id DESC
            )
            SELECT htm.trx_hash, htm.signature
            FROM visible_blocks vb
            JOIN hafd.transactions_multisig htm ON htm.block_id = vb.block_id
            ;', __schema, __schema
        );
    ELSE
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW AS
            WITH hs_data AS MATERIALIZED (
                SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
                FROM hafd.hive_state
            ),
            visible_blocks AS (
                SELECT DISTINCT ON (hb.block_num)
                    hb.block_id
                FROM hafd.blocks hb, %s.context_data_view c, hs_data
                WHERE hb.block_num <= c.min_block
                  AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork
                ORDER BY hb.block_num, hb.block_id DESC
            )
            SELECT htm.trx_hash, htm.signature
            FROM visible_blocks vb
            JOIN hafd.transactions_multisig htm ON htm.block_id = vb.block_id
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

    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW AS
        WITH hs_data AS MATERIALIZED (
            SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
            FROM hafd.hive_state
        ),
        visible_blocks AS (
            SELECT DISTINCT ON (hb.block_num)
                hb.block_id
            FROM hafd.blocks hb, %s.context_data_view c, hs_data
            WHERE hb.block_num <= c.irreversible_block
              AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork
            ORDER BY hb.block_num, hb.block_id DESC
        )
        SELECT htm.trx_hash, htm.signature
        FROM visible_blocks vb
        JOIN hafd.transactions_multisig htm ON htm.block_id = vb.block_id
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
-- accounts_view - Uses block_id from accounts table
-- Keeps JOIN on blocks_view_internal (LEFT JOIN pattern, small table)
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
-- CTE-gated: embeds blocks lookup with DISTINCT ON dedup directly
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
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.account_operations_view AS
            WITH hs_data AS MATERIALIZED (
                SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
                FROM hafd.hive_state
            ),
            visible_blocks AS (
                SELECT DISTINCT ON (hb.block_num)
                    hb.block_id, hb.block_num AS num
                FROM hafd.blocks hb, %s.context_data_view c, hs_data
                WHERE hb.block_num <= c.current_block_num
                  AND (
                      (hb.block_num <= c.irreversible_block
                       AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork)
                      OR
                      (hb.block_num > c.irreversible_block
                       AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
                  )
                ORDER BY hb.block_num, hb.block_id DESC
            )
            SELECT
                vb.num AS block_num,
                hao.account_id, hao.transacting_account_id, hao.account_op_seq_no,
                hao.operation_id,
                hao.op_type_id
            FROM visible_blocks vb
            JOIN hafd.account_operations hao ON hao.block_id = vb.block_id
            ;', __schema, __schema
        );
    ELSE
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.account_operations_view AS
            WITH hs_data AS MATERIALIZED (
                SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
                FROM hafd.hive_state
            ),
            visible_blocks AS (
                SELECT DISTINCT ON (hb.block_num)
                    hb.block_id, hb.block_num AS num
                FROM hafd.blocks hb, %s.context_data_view c, hs_data
                WHERE hb.block_num <= c.min_block
                  AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork
                ORDER BY hb.block_num, hb.block_id DESC
            )
            SELECT
                vb.num AS block_num,
                hao.account_id, hao.transacting_account_id, hao.account_op_seq_no,
                hao.operation_id,
                hao.op_type_id
            FROM visible_blocks vb
            JOIN hafd.account_operations hao ON hao.block_id = vb.block_id
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

    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.account_operations_view AS
        WITH hs_data AS MATERIALIZED (
            SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
            FROM hafd.hive_state
        ),
        visible_blocks AS (
            SELECT DISTINCT ON (hb.block_num)
                hb.block_id, hb.block_num AS num
            FROM hafd.blocks hb, %s.context_data_view c, hs_data
            WHERE hb.block_num <= c.irreversible_block
              AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork
            ORDER BY hb.block_num, hb.block_id DESC
        )
        SELECT
            vb.num AS block_num,
            hao.account_id, hao.transacting_account_id, hao.account_op_seq_no,
            hao.operation_id,
            hao.op_type_id
        FROM visible_blocks vb
        JOIN hafd.account_operations hao ON hao.block_id = vb.block_id
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
-- applied_hardforks_view - Uses block_id from applied_hardforks table
-- CTE-gated: embeds blocks lookup with DISTINCT ON dedup directly
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
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
            WITH hs_data AS MATERIALIZED (
                SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
                FROM hafd.hive_state
            ),
            visible_blocks AS (
                SELECT DISTINCT ON (hb.block_num)
                    hb.block_id, hb.block_num AS num
                FROM hafd.blocks hb, %s.context_data_view c, hs_data
                WHERE hb.block_num <= c.current_block_num
                  AND (
                      (hb.block_num <= c.irreversible_block
                       AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork)
                      OR
                      (hb.block_num > c.irreversible_block
                       AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
                  )
                ORDER BY hb.block_num, hb.block_id DESC
            )
            SELECT hah.hardfork_num, vb.num AS block_num, hah.hardfork_vop_id
            FROM visible_blocks vb
            JOIN hafd.applied_hardforks hah ON hah.block_id = vb.block_id
            ;', __schema, __schema
        );
    ELSE
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
            WITH hs_data AS MATERIALIZED (
                SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
                FROM hafd.hive_state
            ),
            visible_blocks AS (
                SELECT DISTINCT ON (hb.block_num)
                    hb.block_id, hb.block_num AS num
                FROM hafd.blocks hb, %s.context_data_view c, hs_data
                WHERE hb.block_num <= c.min_block
                  AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork
                ORDER BY hb.block_num, hb.block_id DESC
            )
            SELECT hah.hardfork_num, vb.num AS block_num, hah.hardfork_vop_id
            FROM visible_blocks vb
            JOIN hafd.applied_hardforks hah ON hah.block_id = vb.block_id
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

    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
        WITH hs_data AS MATERIALIZED (
            SELECT COALESCE(hafd.block_id_to_fork(consistent_block), 0::bigint) AS max_fork
            FROM hafd.hive_state
        ),
        visible_blocks AS (
            SELECT DISTINCT ON (hb.block_num)
                hb.block_id, hb.block_num AS num
            FROM hafd.blocks hb, %s.context_data_view c, hs_data
            WHERE hb.block_num <= c.irreversible_block
              AND hafd.block_id_to_fork(hb.block_id) <= hs_data.max_fork
            ORDER BY hb.block_num, hb.block_id DESC
        )
        SELECT hah.hardfork_num, vb.num AS block_num, hah.hardfork_vop_id
        FROM visible_blocks vb
        JOIN hafd.applied_hardforks hah ON hah.block_id = vb.block_id
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
