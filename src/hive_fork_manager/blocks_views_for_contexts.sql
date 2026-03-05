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
        LEAST(
              hc.irreversible_block
            , hc.current_block_num
        ) AS min_block
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

CREATE OR REPLACE FUNCTION hive.create_blocks_view( _context_name TEXT )
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
        'CREATE OR REPLACE VIEW %s.blocks_view
            AS
            SELECT t.num,
                t.hash,
                t.prev,
                t.created_at,
                t.producer_account_id,
                t.transaction_merkle_root,
                t.extensions,
                t.witness_signature,
                t.signing_key,
                t.hbd_interest_rate,
                t.total_vesting_fund_hive,
                t.total_vesting_shares,
                t.total_reward_fund_hive,
                t.virtual_supply,
                t.current_supply,
                t.current_hbd_supply,
                t.dhf_interval_ledger
            FROM %s.context_data_view c,
            LATERAL ( SELECT hb.num,
                hb.hash,
                hb.prev,
                hb.created_at,
                hb.producer_account_id,
                hb.transaction_merkle_root,
                hb.extensions,
                hb.witness_signature,
                hb.signing_key,
                hb.hbd_interest_rate,
                hb.total_vesting_fund_hive,
                hb.total_vesting_shares,
                hb.total_reward_fund_hive,
                hb.virtual_supply,
                hb.current_supply,
                hb.current_hbd_supply,
                hb.dhf_interval_ledger
               FROM hafd.blocks hb
               WHERE hb.num <= c.min_block
        ) t;
        ;', __schema, __schema
    );

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

EXECUTE format(
        'CREATE OR REPLACE VIEW %s.blocks_view
        AS
        SELECT hb.num,
            hb.hash,
            hb.prev,
            hb.created_at,
            hb.producer_account_id,
            hb.transaction_merkle_root,
            hb.extensions,
            hb.witness_signature,
            hb.signing_key,
            hb.hbd_interest_rate,
            hb.total_vesting_fund_hive,
            hb.total_vesting_shares,
            hb.total_reward_fund_hive,
            hb.virtual_supply,
            hb.current_supply,
            hb.current_hbd_supply,
            hb.dhf_interval_ledger
        FROM hafd.blocks hb
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

CREATE OR REPLACE FUNCTION hive.create_transactions_view( _context_name TEXT )
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
            SELECT t.block_num,
               t.trx_in_block,
               t.trx_hash,
               t.ref_block_num,
               t.ref_block_prefix,
               t.expiration,
               t.signature
            FROM %s.context_data_view c,
            LATERAL
            (
              SELECT ht.block_num,
                       ht.trx_in_block,
                       ht.trx_hash,
                       ht.ref_block_num,
                       ht.ref_block_prefix,
                       ht.expiration,
                       ht.signature
                    FROM hafd.transactions ht
                    WHERE ht.block_num <= c.min_block
            ) t
            ;'
        , __schema, __schema
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
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.transactions_view AS
        SELECT ht.block_num,
           ht.trx_in_block,
           ht.trx_hash,
           ht.ref_block_num,
           ht.ref_block_prefix,
           ht.expiration,
           ht.signature
        FROM hafd.transactions ht
       ;'
    , __schema
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

CREATE OR REPLACE FUNCTION hive.create_operations_view_extended( _context_name TEXT )
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
            'CREATE OR REPLACE VIEW %s.operations_view_extended
             AS
             SELECT t.id,
                hafd.operation_id_to_block_num( t.id ) as block_num,
                t.trx_in_block,
                t.op_pos,
                t.op_type_id,
                t.timestamp,
                t.body_binary as body_binary,
                t.body_binary::jsonb AS body,
                t.custom_json_type_id
            FROM %s.context_data_view c,
            LATERAL
            (
                SELECT
                  ho.id,
                  ho.trx_in_block,
                  ho.op_pos,
                  ho.op_type_id,
                  b.created_at timestamp,
                  ho.body_binary,
                  ho.custom_json_type_id
                FROM hafd.operations ho
                JOIN hafd.blocks b ON b.num = hafd.operation_id_to_block_num(ho.id)
                WHERE hafd.operation_id_to_block_num(ho.id) <= c.min_block
            ) t
            ;', __schema, __schema
            );
    PERFORM hive.adjust_view_ownership(_context_name, 'operations_view_extended');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_operations_view( _context_name TEXT )
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
        'CREATE OR REPLACE VIEW %s.operations_view
             AS
             SELECT t.id,
                hafd.operation_id_to_block_num( t.id ) as block_num,
                t.trx_in_block,
                t.op_pos,
                t.op_type_id,
                t.body_binary as body_binary,
                t.body_binary::jsonb AS body,
                t.custom_json_type_id
              FROM %s.context_data_view c,
              LATERAL
              (
                SELECT
                  ho.id,
                  ho.trx_in_block,
                  ho.op_pos,
                  ho.op_type_id,
                  ho.body_binary,
                  ho.custom_json_type_id
                  FROM hafd.operations ho
                  WHERE hafd.operation_id_to_block_num(ho.id) <= c.min_block
              ) t
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
        'CREATE OR REPLACE VIEW %s.operations_view_extended
         AS
         SELECT
            ho.id,
            hafd.operation_id_to_block_num( ho.id ) as block_num,
            ho.trx_in_block,
            ho.op_pos,
            ho.op_type_id,
            b.created_at timestamp,
            ho.body_binary as body_binary,
            ho.body_binary::jsonb AS body,
            ho.custom_json_type_id
        FROM hafd.operations ho
        JOIN hafd.blocks b ON b.num = hafd.operation_id_to_block_num(ho.id)
        ;', __schema
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
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.operations_view
         AS
         SELECT
            ho.id,
            hafd.operation_id_to_block_num( ho.id ) as block_num,
            ho.trx_in_block,
            ho.op_pos,
            ho.op_type_id,
            ho.body_binary as body_binary,
            ho.body_binary::jsonb AS body,
            ho.custom_json_type_id
        FROM hafd.operations ho
        ;', __schema
    );
    PERFORM hive.adjust_view_ownership(_context_name, 'operations_view');
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

CREATE OR REPLACE FUNCTION hive.create_signatures_view( _context_name TEXT )
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
            'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW
            AS
            SELECT
                  t.trx_hash
                , t.signature
            FROM %s.context_data_view c,
            LATERAL(
                SELECT
                  htm.trx_hash
                , htm.signature
                FROM hafd.transactions_multisig htm
                JOIN hafd.transactions ht ON ht.trx_hash = htm.trx_hash
                WHERE ht.block_num <= c.min_block
        ) t;'
        , __schema, __schema
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
EXECUTE format(
    'CREATE OR REPLACE VIEW %s.TRANSACTIONS_MULTISIG_VIEW
    AS
    SELECT
          htm.trx_hash
        , htm.signature
    FROM hafd.transactions_multisig htm
    ;'
    , __schema
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

    EXECUTE format(
            'CREATE OR REPLACE VIEW %s.accounts_view AS
            SELECT
               t.id,
               t.name
            FROM %s.context_data_view c,
            LATERAL
            (
              SELECT ha.id,
                     ha.name
                    FROM hafd.accounts ha
                    WHERE COALESCE(ha.block_num,1) <= c.min_block
            ) t
            ;'
        , __schema, __schema
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
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.accounts_view AS
        SELECT
           ha.id,
           ha.name
        FROM hafd.accounts ha
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

CREATE OR REPLACE FUNCTION hive.create_account_operations_view( _context_name TEXT )
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
            SELECT
               hafd.operation_id_to_block_num( t.operation_id ) as block_num,
               t.account_id,
               t.transacting_account_id,
               t.account_op_seq_no,
               t.operation_id,
               t.op_type_id
            FROM %s.context_data_view c,
            LATERAL
            (
              SELECT
                     ha.account_id,
                     ha.transacting_account_id,
                     ha.account_op_seq_no,
                     ha.operation_id,
                     ha.op_type_id
                    FROM hafd.account_operations ha
                    WHERE hafd.operation_id_to_block_num(ha.operation_id) <= c.min_block
            ) t
            ;'
        , __schema, __schema
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
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.account_operations_view AS
        SELECT
           hafd.operation_id_to_block_num( ha.operation_id ) as block_num,
           ha.account_id,
           ha.transacting_account_id,
           ha.account_op_seq_no,
           ha.operation_id,
           ha.op_type_id
        FROM hafd.account_operations ha
        ;'
    , __schema
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


CREATE OR REPLACE FUNCTION hive.create_applied_hardforks_view( _context_name TEXT )
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
            SELECT
               t.hardfork_num,
               t.block_num,
               t.hardfork_vop_id
            FROM %s.context_data_view c,
            LATERAL
            (
              SELECT hr.hardfork_num,
                     hr.block_num,
                     hr.hardfork_vop_id
                    FROM hafd.applied_hardforks hr
                    WHERE hr.block_num <= c.min_block
            ) t
            ;'
        , __schema, __schema
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
EXECUTE format(
        'CREATE OR REPLACE VIEW %s.applied_hardforks_view AS
        SELECT
                 hr.hardfork_num,
                 hr.block_num,
                 hr.hardfork_vop_id
        FROM hafd.applied_hardforks hr
        ;'
    , __schema
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
