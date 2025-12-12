-- =============================================================================
-- View Creation Functions for HAF Contexts
-- =============================================================================
-- These functions create views that present unified block_id tables as if they
-- were the old block_num-based schema. Views use ROW_NUMBER() window function
-- to select canonical rows (highest block_id = most recent fork) per block_num.
--
-- Pattern: ROW_NUMBER() OVER (PARTITION BY block_id_to_num(block_id) ORDER BY block_id DESC)
-- This selects the row from the highest fork_id for each block_num.
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
-- blocks_view
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
        -- Forking context: use window function to select canonical block per block_num
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.blocks_view AS
            SELECT num, hash, prev, created_at, producer_account_id,
                   transaction_merkle_root, extensions, witness_signature,
                   signing_key, hbd_interest_rate, total_vesting_fund_hive,
                   total_vesting_shares, total_reward_fund_hive, virtual_supply,
                   current_supply, current_hbd_supply, dhf_interval_ledger
            FROM (
                SELECT
                    hafd.block_id_to_num(hb.block_id) AS num,
                    hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
                    hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
                    hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
                    hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
                    hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger,
                    ROW_NUMBER() OVER (
                        PARTITION BY hafd.block_id_to_num(hb.block_id)
                        ORDER BY hb.block_id DESC
                    ) AS rn
                FROM hafd.blocks hb, %s.context_data_view c
                WHERE hafd.block_id_to_num(hb.block_id) <= c.current_block_num
                  AND (
                    (hafd.block_id_to_num(hb.block_id) <= c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) = 0)
                    OR
                    (hafd.block_id_to_num(hb.block_id) > c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
                  )
            ) t WHERE rn = 1
            ;', __schema, __schema
        );
    ELSE
        -- Non-forking context: only show irreversible data (fork_id=0)
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.blocks_view AS
            SELECT
                hafd.block_id_to_num(hb.block_id) AS num,
                hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
                hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
                hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
                hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
                hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
            FROM hafd.blocks hb, %s.context_data_view c
            WHERE hafd.block_id_to_num(hb.block_id) <= c.min_block
              AND hafd.block_id_to_fork(hb.block_id) = 0
            ;', __schema, __schema
        );
    END IF;

    PERFORM hive.adjust_view_ownership(_context_name, 'blocks_view');
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

    -- All irreversible: only show data with fork_id=0
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.blocks_view AS
        SELECT
            hafd.block_id_to_num(hb.block_id) AS num,
            hb.hash, hb.prev, hb.created_at, hb.producer_account_id,
            hb.transaction_merkle_root, hb.extensions, hb.witness_signature,
            hb.signing_key, hb.hbd_interest_rate, hb.total_vesting_fund_hive,
            hb.total_vesting_shares, hb.total_reward_fund_hive, hb.virtual_supply,
            hb.current_supply, hb.current_hbd_supply, hb.dhf_interval_ledger
        FROM hafd.blocks hb
        WHERE hafd.block_id_to_fork(hb.block_id) = 0
        ;', __schema
    );

    PERFORM hive.adjust_view_ownership(_context_name, 'blocks_view');
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
    EXECUTE format( 'DROP VIEW IF EXISTS %s.blocks_view CASCADE;', __schema );
END;
$BODY$
;

-- =============================================================================
-- transactions_view
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
        -- Join with canonical blocks to ensure we only include transactions
        -- from blocks that are on the canonical fork path
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.transactions_view AS
            SELECT
                hafd.block_id_to_num(ht.block_id) AS block_num,
                ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
                ht.ref_block_prefix, ht.expiration, ht.signature
            FROM hafd.transactions ht
            JOIN (
                -- Get canonical block_ids using the same logic as blocks_view
                SELECT hb.block_id
                FROM (
                    SELECT
                        hb.block_id,
                        ROW_NUMBER() OVER (
                            PARTITION BY hafd.block_id_to_num(hb.block_id)
                            ORDER BY hb.block_id DESC
                        ) AS rn
                    FROM hafd.blocks hb, %s.context_data_view c
                    WHERE hafd.block_id_to_num(hb.block_id) <= c.current_block_num
                      AND (
                        (hafd.block_id_to_num(hb.block_id) <= c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) = 0)
                        OR
                        (hafd.block_id_to_num(hb.block_id) > c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
                      )
                ) hb WHERE rn = 1
            ) canonical_blocks ON ht.block_id = canonical_blocks.block_id
            ;', __schema, __schema
        );
    ELSE
        -- Non-forking context: only show irreversible data (fork_id=0)
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.transactions_view AS
            SELECT
                hafd.block_id_to_num(ht.block_id) AS block_num,
                ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
                ht.ref_block_prefix, ht.expiration, ht.signature
            FROM hafd.transactions ht
            JOIN (
                SELECT hb.block_id
                FROM hafd.blocks hb, %s.context_data_view c
                WHERE hafd.block_id_to_num(hb.block_id) <= c.min_block
                  AND hafd.block_id_to_fork(hb.block_id) = 0
            ) canonical_blocks ON ht.block_id = canonical_blocks.block_id
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

    -- All irreversible: only show data with fork_id=0
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.transactions_view AS
        SELECT
            hafd.block_id_to_num(ht.block_id) AS block_num,
            ht.trx_in_block, ht.trx_hash, ht.ref_block_num,
            ht.ref_block_prefix, ht.expiration, ht.signature
        FROM hafd.transactions ht
        WHERE hafd.block_id_to_fork(ht.block_id) = 0
        ;', __schema
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
-- operations_view
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
        -- Join with canonical blocks to ensure we only include operations
        -- from blocks that are on the canonical fork path
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.operations_view AS
            SELECT
                hafd.operation_id(hafd.block_id_to_num(ho.block_id), ho.op_type_id, ho.seq_in_block) AS id,
                hafd.block_id_to_num(ho.block_id) AS block_num,
                ho.trx_in_block, ho.op_pos, ho.op_type_id,
                ho.body_binary,
                ho.body_binary::jsonb AS body
            FROM hafd.operations ho
            JOIN (
                SELECT hb.block_id
                FROM (
                    SELECT
                        hb.block_id,
                        ROW_NUMBER() OVER (
                            PARTITION BY hafd.block_id_to_num(hb.block_id)
                            ORDER BY hb.block_id DESC
                        ) AS rn
                    FROM hafd.blocks hb, %s.context_data_view c
                    WHERE hafd.block_id_to_num(hb.block_id) <= c.current_block_num
                      AND (
                        (hafd.block_id_to_num(hb.block_id) <= c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) = 0)
                        OR
                        (hafd.block_id_to_num(hb.block_id) > c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
                      )
                ) hb WHERE rn = 1
            ) canonical_blocks ON ho.block_id = canonical_blocks.block_id
            ;', __schema, __schema
        );
    ELSE
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.operations_view AS
            -- Non-forking context: only show irreversible data (fork_id=0)
            SELECT
                hafd.operation_id(hafd.block_id_to_num(ho.block_id), ho.op_type_id, ho.seq_in_block) AS id,
                hafd.block_id_to_num(ho.block_id) AS block_num,
                ho.trx_in_block, ho.op_pos, ho.op_type_id,
                ho.body_binary,
                ho.body_binary::jsonb AS body
            FROM hafd.operations ho
            JOIN (
                SELECT hb.block_id
                FROM hafd.blocks hb, %s.context_data_view c
                WHERE hafd.block_id_to_num(hb.block_id) <= c.min_block
                  AND hafd.block_id_to_fork(hb.block_id) = 0
            ) canonical_blocks ON ho.block_id = canonical_blocks.block_id
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
        -- Join with canonical blocks to ensure we only include operations
        -- from blocks that are on the canonical fork path
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.operations_view_extended AS
            SELECT
                hafd.operation_id(hafd.block_id_to_num(ho.block_id), ho.op_type_id, ho.seq_in_block) AS id,
                hafd.block_id_to_num(ho.block_id) AS block_num,
                ho.trx_in_block, ho.op_pos, ho.op_type_id,
                b.created_at AS timestamp,
                ho.body_binary,
                ho.body_binary::jsonb AS body
            FROM hafd.operations ho
            JOIN hafd.blocks b ON b.block_id = ho.block_id
            JOIN (
                SELECT hb.block_id
                FROM (
                    SELECT
                        hb.block_id,
                        ROW_NUMBER() OVER (
                            PARTITION BY hafd.block_id_to_num(hb.block_id)
                            ORDER BY hb.block_id DESC
                        ) AS rn
                    FROM hafd.blocks hb, %s.context_data_view c
                    WHERE hafd.block_id_to_num(hb.block_id) <= c.current_block_num
                      AND (
                        (hafd.block_id_to_num(hb.block_id) <= c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) = 0)
                        OR
                        (hafd.block_id_to_num(hb.block_id) > c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
                      )
                ) hb WHERE rn = 1
            ) canonical_blocks ON ho.block_id = canonical_blocks.block_id
            ;', __schema, __schema
        );
    ELSE
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.operations_view_extended AS
            SELECT
                hafd.operation_id(hafd.block_id_to_num(ho.block_id), ho.op_type_id, ho.seq_in_block) AS id,
                -- Non-forking context: only show irreversible data (fork_id=0)
                hafd.block_id_to_num(ho.block_id) AS block_num,
                ho.trx_in_block, ho.op_pos, ho.op_type_id,
                b.created_at AS timestamp,
                ho.body_binary,
                ho.body_binary::jsonb AS body
            FROM hafd.operations ho
            JOIN hafd.blocks b ON b.block_id = ho.block_id
            JOIN (
                SELECT hb.block_id
                FROM hafd.blocks hb, %s.context_data_view c
                WHERE hafd.block_id_to_num(hb.block_id) <= c.min_block
                  AND hafd.block_id_to_fork(hb.block_id) = 0
            ) canonical_blocks ON ho.block_id = canonical_blocks.block_id
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

    -- All irreversible: only show data with fork_id=0
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view AS
        SELECT
            hafd.operation_id(hafd.block_id_to_num(ho.block_id), ho.op_type_id, ho.seq_in_block) AS id,
            hafd.block_id_to_num(ho.block_id) AS block_num,
            ho.trx_in_block, ho.op_pos, ho.op_type_id,
            ho.body_binary,
            ho.body_binary::jsonb AS body
        FROM hafd.operations ho
        WHERE hafd.block_id_to_fork(ho.block_id) = 0
        ;', __schema
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

    -- All irreversible: only show data with fork_id=0
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view_extended AS
        SELECT
            hafd.operation_id(hafd.block_id_to_num(ho.block_id), ho.op_type_id, ho.seq_in_block) AS id,
            hafd.block_id_to_num(ho.block_id) AS block_num,
            ho.trx_in_block, ho.op_pos, ho.op_type_id,
            b.created_at AS timestamp,
            ho.body_binary,
            ho.body_binary::jsonb AS body
        FROM hafd.operations ho
        JOIN hafd.blocks b ON b.block_id = ho.block_id
        WHERE hafd.block_id_to_fork(ho.block_id) = 0
        ;', __schema
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
-- signatures_view (transactions_multisig)
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
        -- Join with canonical blocks to ensure we only include signatures
        -- from blocks that are on the canonical fork path
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW AS
            SELECT ht.trx_hash, htm.signature
            FROM hafd.transactions_multisig htm
            JOIN hafd.transactions ht ON ht.block_id = htm.block_id AND ht.trx_in_block = htm.trx_in_block
            JOIN (
                SELECT hb.block_id
                FROM (
                    SELECT
                        hb.block_id,
                        ROW_NUMBER() OVER (
                            PARTITION BY hafd.block_id_to_num(hb.block_id)
                            ORDER BY hb.block_id DESC
                        ) AS rn
                    FROM hafd.blocks hb, %s.context_data_view c
                    WHERE hafd.block_id_to_num(hb.block_id) <= c.current_block_num
                      AND (
                        (hafd.block_id_to_num(hb.block_id) <= c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) = 0)
                        OR
                        (hafd.block_id_to_num(hb.block_id) > c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
                      )
                ) hb WHERE rn = 1
            ) canonical_blocks ON htm.block_id = canonical_blocks.block_id
            ;', __schema, __schema
        );
    ELSE
        -- Non-forking context: only show irreversible data (fork_id=0)
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW AS
            SELECT ht.trx_hash, htm.signature
            FROM hafd.transactions_multisig htm
            JOIN hafd.transactions ht ON ht.block_id = htm.block_id AND ht.trx_in_block = htm.trx_in_block
            JOIN (
                SELECT hb.block_id
                FROM hafd.blocks hb, %s.context_data_view c
                WHERE hafd.block_id_to_num(hb.block_id) <= c.min_block
                  AND hafd.block_id_to_fork(hb.block_id) = 0
            ) canonical_blocks ON htm.block_id = canonical_blocks.block_id
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

    -- All irreversible: only show data with fork_id=0
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW AS
        SELECT ht.trx_hash, htm.signature
        FROM hafd.transactions_multisig htm
        JOIN hafd.transactions ht ON ht.block_id = htm.block_id AND ht.trx_in_block = htm.trx_in_block
        WHERE hafd.block_id_to_fork(htm.block_id) = 0
        ;', __schema
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
-- accounts_view
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

    IF __is_forking THEN
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.accounts_view AS
            SELECT id, name
            FROM (
                SELECT
                    ha.id, ha.name,
                    ROW_NUMBER() OVER (
                        PARTITION BY ha.id
                        ORDER BY ha.block_id DESC
                    ) AS rn
                FROM hafd.accounts ha, %s.context_data_view c
                WHERE hafd.block_id_to_num(ha.block_id) <= c.current_block_num
                  AND (
                    (hafd.block_id_to_num(ha.block_id) <= c.irreversible_block AND hafd.block_id_to_fork(ha.block_id) = 0)
                    OR
                    (hafd.block_id_to_num(ha.block_id) > c.irreversible_block AND hafd.block_id_to_fork(ha.block_id) <= c.fork_id)
                  )
            ) t WHERE rn = 1
            ;', __schema, __schema
        );
    ELSE
        EXECUTE format(
            -- Non-forking context: only show irreversible data (fork_id=0)
            'CREATE OR REPLACE VIEW %s.accounts_view AS
            SELECT ha.id, ha.name
            FROM hafd.accounts ha, %s.context_data_view c
            WHERE hafd.block_id_to_num(ha.block_id) <= c.min_block
              AND hafd.block_id_to_fork(ha.block_id) = 0
            ;', __schema, __schema
        );
    END IF;
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

    -- All irreversible: only show data with fork_id=0
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.accounts_view AS
        SELECT ha.id, ha.name
        FROM hafd.accounts ha
        WHERE hafd.block_id_to_fork(ha.block_id) = 0
        ;', __schema
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
-- account_operations_view
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
        -- Join with canonical blocks to ensure we only include account_operations
        -- from blocks that are on the canonical fork path
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.account_operations_view AS
            SELECT
                hafd.block_id_to_num(hao.block_id) AS block_num,
                hao.account_id, hao.transacting_account_id, hao.account_op_seq_no,
                hafd.operation_id(hafd.block_id_to_num(hao.block_id), ho.op_type_id, hao.seq_in_block) AS operation_id,
                ho.op_type_id
            FROM hafd.account_operations hao
            JOIN hafd.operations ho ON ho.block_id = hao.block_id AND ho.seq_in_block = hao.seq_in_block
            JOIN (
                SELECT hb.block_id
                FROM (
                    SELECT
                        hb.block_id,
                        ROW_NUMBER() OVER (
                            PARTITION BY hafd.block_id_to_num(hb.block_id)
                            ORDER BY hb.block_id DESC
                        ) AS rn
                    FROM hafd.blocks hb, %s.context_data_view c
                    WHERE hafd.block_id_to_num(hb.block_id) <= c.current_block_num
                      AND (
                        (hafd.block_id_to_num(hb.block_id) <= c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) = 0)
                        OR
                        (hafd.block_id_to_num(hb.block_id) > c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
                      )
                ) hb WHERE rn = 1
            ) canonical_blocks ON hao.block_id = canonical_blocks.block_id
            ;', __schema, __schema
        );
    ELSE
        EXECUTE format(
            -- Non-forking context: only show irreversible data (fork_id=0)
            'CREATE OR REPLACE VIEW %s.account_operations_view AS
            SELECT
                hafd.block_id_to_num(hao.block_id) AS block_num,
                hao.account_id, hao.transacting_account_id, hao.account_op_seq_no,
                hafd.operation_id(hafd.block_id_to_num(hao.block_id), ho.op_type_id, hao.seq_in_block) AS operation_id,
                ho.op_type_id
            FROM hafd.account_operations hao
            JOIN hafd.operations ho ON ho.block_id = hao.block_id AND ho.seq_in_block = hao.seq_in_block
            JOIN (
                SELECT hb.block_id
                FROM hafd.blocks hb, %s.context_data_view c
                WHERE hafd.block_id_to_num(hb.block_id) <= c.min_block
                  AND hafd.block_id_to_fork(hb.block_id) = 0
            ) canonical_blocks ON hao.block_id = canonical_blocks.block_id
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

    -- All irreversible: only show data with fork_id=0
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.account_operations_view AS
        SELECT
            hafd.block_id_to_num(hao.block_id) AS block_num,
            hao.account_id, hao.transacting_account_id, hao.account_op_seq_no,
            hafd.operation_id(hafd.block_id_to_num(hao.block_id), ho.op_type_id, hao.seq_in_block) AS operation_id,
            ho.op_type_id
        FROM hafd.account_operations hao
        JOIN hafd.operations ho ON ho.block_id = hao.block_id AND ho.seq_in_block = hao.seq_in_block
        WHERE hafd.block_id_to_fork(hao.block_id) = 0
        ;', __schema
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
-- applied_hardforks_view
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
        -- Join with canonical blocks to ensure we only include hardforks
        -- from blocks that are on the canonical fork path
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
            SELECT hardfork_num, block_num, hardfork_vop_id
            FROM (
                SELECT
                    hah.hardfork_num,
                    hafd.block_id_to_num(hah.block_id) AS block_num,
                    hah.hardfork_vop_id,
                    ROW_NUMBER() OVER (
                        PARTITION BY hah.hardfork_num
                        ORDER BY hah.block_id DESC
                    ) AS rn
                FROM hafd.applied_hardforks hah
                JOIN (
                    -- Get canonical block_ids using the same logic as blocks_view
                    SELECT hb.block_id
                    FROM (
                        SELECT
                            hb.block_id,
                            ROW_NUMBER() OVER (
                                PARTITION BY hafd.block_id_to_num(hb.block_id)
                                ORDER BY hb.block_id DESC
                            ) AS rn
                        FROM hafd.blocks hb, %s.context_data_view c
                        WHERE hafd.block_id_to_num(hb.block_id) <= c.current_block_num
                          AND (
                            (hafd.block_id_to_num(hb.block_id) <= c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) = 0)
                            OR
                            (hafd.block_id_to_num(hb.block_id) > c.irreversible_block AND hafd.block_id_to_fork(hb.block_id) <= c.fork_id)
                          )
                    ) hb WHERE rn = 1
                ) canonical_blocks ON hah.block_id = canonical_blocks.block_id
            ) t WHERE rn = 1
            ;', __schema, __schema
        );
    ELSE
        -- Non-forking context: only show irreversible data (fork_id=0)
        EXECUTE format(
            'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
            SELECT hardfork_num, block_num, hardfork_vop_id
            FROM (
                SELECT
                    hah.hardfork_num,
                    hafd.block_id_to_num(hah.block_id) AS block_num,
                    hah.hardfork_vop_id,
                    ROW_NUMBER() OVER (
                        PARTITION BY hah.hardfork_num
                        ORDER BY hah.block_id DESC
                    ) AS rn
                FROM hafd.applied_hardforks hah
                JOIN (
                    SELECT hb.block_id
                    FROM hafd.blocks hb, %s.context_data_view c
                    WHERE hafd.block_id_to_num(hb.block_id) <= c.min_block
                      AND hafd.block_id_to_fork(hb.block_id) = 0
                ) canonical_blocks ON hah.block_id = canonical_blocks.block_id
            ) t WHERE rn = 1
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

    -- All irreversible: only show data with fork_id=0
    EXECUTE format(
        'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
        SELECT
            hah.hardfork_num,
            hafd.block_id_to_num(hah.block_id) AS block_num,
            hah.hardfork_vop_id
        FROM hafd.applied_hardforks hah
        WHERE hafd.block_id_to_fork(hah.block_id) = 0
        ;', __schema
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
