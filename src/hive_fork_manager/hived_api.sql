CREATE OR REPLACE FUNCTION hive.back_from_fork( _block_num_before_fork INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __fork_id BIGINT;
BEGIN
    INSERT INTO hive.fork(block_num, time_of_fork)
    VALUES( _block_num_before_fork, LOCALTIMESTAMP );

    SELECT MAX(hf.id) INTO __fork_id FROM hive.fork hf;
    INSERT INTO hive.events_queue( event, block_num )
    VALUES( 'BACK_FROM_FORK', __fork_id );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.push_block(
      _block hive.blocks
    , _transactions hive.transactions[]
    , _signatures hive.transactions_multisig[]
    , _operations hive.operations[]
    , _accounts hive.accounts[]
    , _account_operations hive.account_operations[]
    , _applied_hardforks hive.applied_hardforks[]
)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __fork_id hive.fork.id%TYPE;
BEGIN
    SELECT hf.id
    INTO __fork_id
    FROM hive.fork hf ORDER BY hf.id DESC LIMIT 1;

    INSERT INTO hive.events_queue( event, block_num )
        VALUES( 'NEW_BLOCK', _block.num );

    INSERT INTO hive.blocks_reversible VALUES( _block.*, __fork_id );
    INSERT INTO hive.transactions_reversible VALUES( ( unnest( _transactions ) ).*, __fork_id );
    INSERT INTO hive.transactions_multisig_reversible VALUES( ( unnest( _signatures ) ).*, __fork_id );
    INSERT INTO hive.operations_reversible(id, block_num, trx_in_block, op_pos, op_type_id, timestamp, body_binary, fork_id)
      SELECT id, block_num, trx_in_block, op_pos, op_type_id, timestamp, body_binary, __fork_id FROM unnest( _operations );
    INSERT INTO hive.accounts_reversible VALUES( ( unnest( _accounts ) ).*, __fork_id );
    INSERT INTO hive.account_operations_reversible VALUES( ( unnest( _account_operations ) ).*, __fork_id );
    INSERT INTO hive.applied_hardforks_reversible VALUES( ( unnest( _applied_hardforks ) ).*, __fork_id );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.set_irreversible( _block_num INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __irreversible_head_block hive.blocks.num%TYPE;
    __first_block hive.blocks.num%TYPE;
BEGIN
    SELECT COALESCE( MAX( num ), 0 ) INTO __irreversible_head_block FROM hive.blocks;

    SELECT COALESCE( first_block_to_sync, 1 ) INTO __first_block FROM hive.irreversible_data;

    if ( _block_num < __first_block ) THEN
        RETURN;
    END IF;

    IF ( _block_num < __irreversible_head_block ) THEN
        RETURN;
    END IF;

    PERFORM hive.remove_unecessary_events( _block_num );

    -- application contexts will use the event to clear data in shadow tables
    INSERT INTO hive.events_queue( event, block_num )
    VALUES( 'NEW_IRREVERSIBLE', _block_num );

    -- copy to irreversible
    PERFORM hive.copy_blocks_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_transactions_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_operations_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_signatures_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_accounts_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_account_operations_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_applied_hardforks_to_irreversible( __irreversible_head_block, _block_num );

    --try to increase irreversible blocks for every context
    PERFORM hive.refresh_irreversible_block_for_all_contexts( _block_num );

    -- remove unneeded blocks and events
    PERFORM hive.remove_obsolete_reversible_data( _block_num );

    UPDATE hive.irreversible_data SET consistent_block = _block_num;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.end_massive_sync( _block_num INTEGER )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
     -- remove all events less than lowest context events_id
    PERFORM hive.remove_unecessary_events( _block_num );

    INSERT INTO hive.events_queue( event, block_num )
    VALUES ( 'MASSIVE_SYNC'::hive.event_type, _block_num );

    --try to increase irreversible blocks for every context
    PERFORM hive.refresh_irreversible_block_for_all_contexts( _block_num );

    PERFORM hive.remove_obsolete_reversible_data( _block_num );

    UPDATE hive.irreversible_data SET consistent_block = _block_num;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.set_irreversible_dirty()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    UPDATE hive.irreversible_data SET is_dirty = TRUE;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.set_irreversible_not_dirty()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    UPDATE hive.irreversible_data SET is_dirty = FALSE;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.is_irreversible_dirty()
    RETURNS BOOL
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __is_dirty BOOL := FALSE;
BEGIN
    SELECT is_dirty INTO __is_dirty FROM hive.irreversible_data;
    RETURN __is_dirty;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.disable_indexes_of_irreversible()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'blocks' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'transactions' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'transactions_multisig' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'operations' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'applied_hardforks' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'accounts' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'account_operations' );


END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.disable_fk_of_irreversible()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'irreversible_data' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'blocks' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'transactions' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'transactions_multisig' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'operations' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'applied_hardforks' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'accounts' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'account_operations' );

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.enable_indexes_of_irreversible()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.restore_indexes( 'hive.blocks' );
    PERFORM hive.restore_indexes( 'hive.transactions' );
    PERFORM hive.restore_indexes( 'hive.transactions_multisig' );
    PERFORM hive.restore_indexes( 'hive.operations' );
    PERFORM hive.restore_indexes( 'hive.applied_hardforks' );
    PERFORM hive.restore_indexes( 'hive.accounts' );
    PERFORM hive.restore_indexes( 'hive.account_operations' );
    PERFORM hive.restore_indexes( 'hive.irreversible_data' );


END;
$BODY$
SET maintenance_work_mem TO '6GB';
;

CREATE OR REPLACE FUNCTION hive.enable_fk_of_irreversible()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.restore_foreign_keys( 'hive.blocks' );
    PERFORM hive.restore_foreign_keys( 'hive.transactions' );
    PERFORM hive.restore_foreign_keys( 'hive.transactions_multisig' );
    PERFORM hive.restore_foreign_keys( 'hive.operations' );
    PERFORM hive.restore_foreign_keys( 'hive.applied_hardforks' );
    PERFORM hive.restore_foreign_keys( 'hive.irreversible_data' );
    PERFORM hive.restore_foreign_keys( 'hive.accounts' );
    PERFORM hive.restore_foreign_keys( 'hive.account_operations' );

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.disable_indexes_of_reversible()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'blocks_reversible' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'transactions_reversible' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'transactions_multisig_reversible' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'operations_reversible' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'applied_hardforks_reversible' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'accounts_reversible' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'account_operations_reversible' );



    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'blocks_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'transactions_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'transactions_multisig_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'operations_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'applied_hardforks_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'accounts_reversible' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'account_operations_reversible' );



END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.enable_indexes_of_reversible()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.restore_indexes( 'hive.blocks_reversible' );
    PERFORM hive.restore_indexes( 'hive.transactions_reversible' );
    PERFORM hive.restore_indexes( 'hive.transactions_multisig_reversible' );
    PERFORM hive.restore_indexes( 'hive.operations_reversible' );
    PERFORM hive.restore_indexes( 'hive.accounts_reversible' );
    PERFORM hive.restore_indexes( 'hive.account_operations_reversible' );
    PERFORM hive.restore_indexes( 'hive.applied_hardforks_reversible' );



    PERFORM hive.restore_foreign_keys( 'hive.blocks_reversible' );
    PERFORM hive.restore_foreign_keys( 'hive.transactions_reversible' );
    PERFORM hive.restore_foreign_keys( 'hive.transactions_multisig_reversible' );
    PERFORM hive.restore_foreign_keys( 'hive.operations_reversible' );
    PERFORM hive.restore_foreign_keys( 'hive.accounts_reversible' );
    PERFORM hive.restore_foreign_keys( 'hive.account_operations_reversible' );
    PERFORM hive.restore_foreign_keys( 'hive.applied_hardforks_reversible' );

END;
$BODY$
;



CREATE OR REPLACE FUNCTION hive.connect( _git_sha TEXT, _block_num hive.blocks.num%TYPE, _first_blocknum hive.blocks.num%TYPE )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.remove_inconsistent_irreversible_data();
    PERFORM hive.back_from_fork( _block_num );
    INSERT INTO hive.hived_connections( block_num, git_sha, time )
    VALUES( _block_num, _git_sha, now() );

    UPDATE hive.irreversible_data SET first_block_to_sync = _first_blocknum;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.are_indexes_dropped()
    RETURNS BOOL
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __number_of_dropped_indexes INT;
BEGIN
    SELECT COUNT(*) FROM hive.indexes_constraints
    WHERE is_index
    INTO __number_of_dropped_indexes;
    IF ( __number_of_dropped_indexes = 0 ) THEN
        RETURN FALSE;
    ELSE
        RETURN TRUE;
    END IF;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.are_fk_dropped()
    RETURNS BOOL
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __number_of_dropped_fk INT;
BEGIN
    SELECT COUNT(*) FROM hive.indexes_constraints
    WHERE is_foreign_key
    INTO __number_of_dropped_fk;
    IF ( __number_of_dropped_fk = 0 ) THEN
        RETURN FALSE;
    ELSE
        RETURN TRUE;
    END IF;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.initialize_extension_data()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __events_id BIGINT := 0;
BEGIN
    IF EXISTS ( SELECT 1 FROM hive.blocks WHERE num = hive.block_sink_num() LIMIT 1 ) THEN
        SELECT MAX(eq.id) + 1 FROM hive.events_queue eq WHERE eq.id != hive.unreachable_event_id() INTO __events_id;
        PERFORM SETVAL( 'hive.events_queue_id_seq', __events_id, false );
        PERFORM hive.create_database_hash('hive');
        RETURN;
    END IF;
    SET CONSTRAINTS ALL DEFERRED;

    INSERT INTO hive.irreversible_data VALUES(1,NULL, FALSE, NULL) ON CONFLICT DO NOTHING;
    INSERT INTO hive.events_queue VALUES( 0, 'NEW_IRREVERSIBLE', 0 ) ON CONFLICT DO NOTHING;
    INSERT INTO hive.events_queue VALUES( hive.unreachable_event_id(), 'NEW_BLOCK', 2147483647 ) ON CONFLICT DO NOTHING;
    SELECT MAX(eq.id) + 1 FROM hive.events_queue eq WHERE eq.id != hive.unreachable_event_id() INTO __events_id;
    PERFORM SETVAL( 'hive.events_queue_id_seq', __events_id, false );

    INSERT INTO hive.fork(block_num, time_of_fork) VALUES( 1, '2016-03-24 16:05:00'::timestamp ) ON CONFLICT DO NOTHING;

    INSERT INTO hive.blocks VALUES(
          hive.block_sink_num() --num
        , 'x00'::bytea --hash bytea NOT NULL
        , 'x00'::bytea --prev bytea NOT NULL
        , '0001-01-01 00:00:00-07'::timestamp -- created_at timestamp without time zone NOT NULL
        , hive.account_sink_id() -- producer_account_id integer NOT NULL,
        , 'x00'::bytea -- transaction_merkle_root bytea NOT NULL,
        , '[]'::jsonb -- extensions jsonb,
        , 'x00'::bytea -- witness_signature bytea NOT NULL,
        , ''::TEXT -- signing_key text COLLATE pg_catalog."default" NOT NULL
        , 0::hive.interest_rate -- hbd_interest_rate
        , 0::hive.hive_amount -- total_vesting_fund_hive
        , 0::hive.vest_amount -- total_vesting_shares
        , 0::hive.hive_amount -- total_reward_fund_hive
        , 0::hive.hive_amount -- virtual_supply
        , 0::hive.hive_amount -- current_supply
        , 0::hive.hbd_amount  -- current_hbd_supply
        , 0::hive.hbd_amount -- dhf_interval_ledger
    )
    ON CONFLICT DO NOTHING;

    INSERT INTO hive.accounts VALUES(hive.account_sink_id(),'', 0) ON CONFLICT DO NOTHING;

    PERFORM hive.create_database_hash('hive');
END;
$BODY$
;
