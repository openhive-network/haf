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
        -- Note: <= (not =) for irreversible allows blocks from massive sync (fork_id=0) when
        --       consistent_block has higher fork_id
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
            AND NOT EXISTS (
                SELECT 1 FROM hafd.blocks hb2
                WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(hb.block_id)
                  AND (
                      (hafd.block_id_to_num(hb2.block_id) <= c.irreversible_block
                       AND hafd.block_id_to_fork(hb2.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0))
                      OR
                      (hafd.block_id_to_num(hb2.block_id) > c.irreversible_block
                       AND hafd.block_id_to_fork(hb2.block_id) <= c.fork_id)
                  )
                  AND hb2.block_id > hb.block_id
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
        -- Non-forking context: show blocks up to min_block using NOT EXISTS
        -- Uses same fork visibility rule as forking contexts for irreversible:
        --   fork_id <= consistent_block's fork_id
        -- This allows blocks from massive sync (fork_id=0) when consistent_block has higher fork_id,
        -- while filtering out blocks from forks beyond the consistent fork
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
            WHERE hafd.block_id_to_num(hb.block_id) <= c.min_block
              AND hafd.block_id_to_fork(hb.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0)
            AND NOT EXISTS (
                SELECT 1 FROM hafd.blocks hb2
                WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(hb.block_id)
                  AND hafd.block_id_to_fork(hb2.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0)
                  AND hb2.block_id > hb.block_id
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

    -- All irreversible: canonical block selection using NOT EXISTS pattern
    -- Uses fork visibility rule: fork_id <= consistent_block's fork_id
    -- This allows blocks from massive sync (fork_id=0) when consistent_block has higher fork_id,
    -- while filtering out blocks from forks beyond the consistent fork
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
        WHERE hafd.block_id_to_num(hb.block_id) <= c.irreversible_block
          AND hafd.block_id_to_fork(hb.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0)
        AND NOT EXISTS (
            SELECT 1 FROM hafd.blocks hb2
            WHERE hafd.block_id_to_num(hb2.block_id) = hafd.block_id_to_num(hb.block_id)
              AND hafd.block_id_to_fork(hb2.block_id) <= COALESCE(hafd.block_id_to_fork(hs.consistent_block), 0)
              AND hb2.block_id > hb.block_id
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

        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.transactions_view AS
            SELECT b.num AS block_num, ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
                   ht.ref_block_prefix, ht.expiration, ht.signature
            FROM hafd.transactions ht
            JOIN %s.blocks_view_internal b ON b.block_id = ht.block_id
            ;', __schema, __schema
        );
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

    -- All irreversible: show all transactions (no fork filtering needed)
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.transactions_view AS
        SELECT b.num AS block_num, ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
               ht.ref_block_prefix, ht.expiration, ht.signature
        FROM hafd.transactions ht
        JOIN %s.blocks_view_internal b ON b.block_id = ht.block_id
        , %s.context_data_view c
        WHERE b.num <= c.irreversible_block
        ;', __schema, __schema, __schema
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

        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.operations_view AS
            SELECT
                ho.id,
                b.num AS block_num,
                ho.trx_in_block, ho.op_pos,
                hafd.operation_id_to_type_id(ho.id) AS op_type_id,
                ho.body_binary,
                ho.body_binary::jsonb AS body
            FROM hafd.operations ho
            JOIN %s.blocks_view_internal b ON b.block_id = ho.block_id
            ;', __schema, __schema
        );
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

        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.operations_view_extended AS
            SELECT
                ho.id,
                b.num AS block_num,
                ho.trx_in_block, ho.op_pos,
                hafd.operation_id_to_type_id(ho.id) AS op_type_id,
                b.created_at AS timestamp,
                ho.body_binary,
                ho.body_binary::jsonb AS body
            FROM hafd.operations ho
            JOIN %s.blocks_view_internal b ON b.block_id = ho.block_id
            ;', __schema, __schema
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

    -- All irreversible: show all operations (no fork filtering needed)
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view AS
        SELECT
            ho.id,
            b.num AS block_num,
            ho.trx_in_block, ho.op_pos,
            hafd.operation_id_to_type_id(ho.id) AS op_type_id,
            ho.body_binary,
            ho.body_binary::jsonb AS body
        FROM hafd.operations ho
        JOIN %s.blocks_view_internal b ON b.block_id = ho.block_id
        , %s.context_data_view c
        WHERE b.num <= c.irreversible_block
        ;', __schema, __schema, __schema
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

    -- All irreversible: show all operations with timestamps
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view_extended AS
        SELECT
            ho.id,
            b.num AS block_num,
            ho.trx_in_block, ho.op_pos,
            hafd.operation_id_to_type_id(ho.id) AS op_type_id,
            b.created_at AS timestamp,
            ho.body_binary,
            ho.body_binary::jsonb AS body
        FROM hafd.operations ho
        JOIN %s.blocks_view_internal b ON b.block_id = ho.block_id
        , %s.context_data_view c
        WHERE b.num <= c.irreversible_block
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
        , %s.context_data_view c
        WHERE b.num <= c.irreversible_block
        ;', __schema, __schema, __schema
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
    __is_forking BOOL;
BEGIN
    SELECT hc.schema, hc.is_forking INTO __schema, __is_forking
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.accounts_view AS
            SELECT ha.id, ha.name
            FROM hafd.accounts ha
            LEFT JOIN %s.blocks_view_internal b ON b.block_id = ha.block_id
            , %s.context_data_view c
            WHERE ha.block_id IS NULL OR b.block_id IS NOT NULL
            ;', __schema, __schema, __schema
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
        , %s.context_data_view c
        WHERE (ha.block_id IS NULL OR b.block_id IS NOT NULL)
        AND b.num <= c.irreversible_block
        ;', __schema, __schema, __schema
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

        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.account_operations_view AS
            SELECT
                b.num AS block_num,
                hao.account_id, hao.transacting_account_id, hao.account_op_seq_no,
                ho.id AS operation_id,
                hafd.operation_id_to_type_id(ho.id) AS op_type_id
            FROM hafd.account_operations hao
            JOIN hafd.operations ho ON ho.block_id = hao.block_id AND hafd.operation_id_to_pos(ho.id) = hao.seq_in_block
            JOIN %s.blocks_view_internal b ON b.block_id = hao.block_id
            ;', __schema, __schema
        );
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
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.account_operations_view AS
        SELECT
            b.num AS block_num,
            hao.account_id, hao.transacting_account_id, hao.account_op_seq_no,
            ho.id AS operation_id,
            hafd.operation_id_to_type_id(ho.id) AS op_type_id
        FROM hafd.account_operations hao
        JOIN hafd.operations ho ON ho.block_id = hao.block_id AND hafd.operation_id_to_pos(ho.id) = hao.seq_in_block
        JOIN %s.blocks_view_internal b ON b.block_id = hao.block_id
        , %s.context_data_view c
        WHERE b.num <= c.irreversible_block
        ;', __schema, __schema, __schema
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
        , %s.context_data_view c
        WHERE b.num <= c.irreversible_block
        ;', __schema, __schema, __schema
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
