CREATE OR REPLACE FUNCTION hive.back_from_fork( _block_num_before_fork INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __fork_id BIGINT;
BEGIN
    PERFORM hive.dlog('<no-context>', '"Entering back_from_fork" _block_num_before_fork=%I', _block_num_before_fork);
    INSERT INTO hive.fork(block_num, time_of_fork)
    VALUES( _block_num_before_fork, LOCALTIMESTAMP );

    SELECT MAX(hf.id) INTO __fork_id FROM hive.fork hf;
    INSERT INTO hive.events_queue( event, block_num )
    VALUES( 'BACK_FROM_FORK', __fork_id );
    PERFORM hive.dlog('<no-context>', '"Exiting back_from_fork" _block_num_before_fork=%I', _block_num_before_fork);
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
    __transactions TEXT = array_to_string( _transactions, ',' );
    __signatures TEXT = array_to_string( _signatures, ',' );
    __operations TEXT = array_to_string( _operations, ',' );
    __accounts TEXT = array_to_string( _accounts, ',' );
    __account_operations TEXT = array_to_string( _account_operations, ',' );
BEGIN
    PERFORM hive.dlog('<no-context>', '"Entering push_block" _block=%s, _transactions=%s, _signatures=%s, _operations=%s, _accounts=%s, _account_operations=%s',
    _block::TEXT, __transactions, __signatures, __operations, __accounts, __account_operations);
    SELECT hf.id
    INTO __fork_id
    FROM hive.fork hf ORDER BY hf.id DESC LIMIT 1;

    INSERT INTO hive.events_queue( event, block_num )
        VALUES( 'NEW_BLOCK', _block.num );

    INSERT INTO hive.blocks_reversible VALUES( _block.*, __fork_id );
    INSERT INTO hive.transactions_reversible VALUES( ( unnest( _transactions ) ).*, __fork_id );
    INSERT INTO hive.transactions_multisig_reversible VALUES( ( unnest( _signatures ) ).*, __fork_id );
    INSERT INTO hive.operations_reversible VALUES( ( unnest( _operations ) ).*, __fork_id );
    INSERT INTO hive.accounts_reversible VALUES( ( unnest( _accounts ) ).*, __fork_id );
    INSERT INTO hive.account_operations_reversible VALUES( ( unnest( _account_operations ) ).*, __fork_id );
    INSERT INTO hive.applied_hardforks_reversible VALUES( ( unnest( _applied_hardforks ) ).*, __fork_id );
    PERFORM hive.dlog('<no-context>', '"Exiting push_block" _block=%s, _transactions=%s, _signatures=%s, _operations=%s, _accounts=%s, _account_operations=%s',
    _block::TEXT, __transactions, __signatures, __operations, __accounts, __account_operations);
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
BEGIN
    PERFORM hive.dlog('<no-context>', '"Entering set_irreversible" _block_num=%I', _block_num);
    SELECT COALESCE( MAX( num ), 0 ) INTO __irreversible_head_block FROM hive.blocks;
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
    PERFORM hive.dlog('<no-context>', '"Exiting set_irreversible" _block_num=%I', _block_num);
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
    PERFORM hive.dlog('<no-context>', '"Entering end_massive_sync" _block_num=%I', _block_num);
     -- remove all events less than lowest context events_id
    PERFORM hive.remove_unecessary_events( _block_num );

    INSERT INTO hive.events_queue( event, block_num )
    VALUES ( 'MASSIVE_SYNC'::hive.event_type, _block_num );

    --try to increase irreversible blocks for every context
    PERFORM hive.refresh_irreversible_block_for_all_contexts( _block_num );

    PERFORM hive.remove_obsolete_reversible_data( _block_num );

    UPDATE hive.irreversible_data SET consistent_block = _block_num;
    PERFORM hive.dlog('<no-context>', '"Exiting end_massive_sync" _block_num=%I', _block_num);
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
    PERFORM hive.dlog('<no-context>', '"Entering set_irreversible_dirty"');
    UPDATE hive.irreversible_data SET is_dirty = TRUE;
    PERFORM hive.dlog('<no-context>', '"Exiting set_irreversible_dirty"');
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
    PERFORM hive.dlog('<no-context>', '"Entering set_irreversible_not_dirty"');
    UPDATE hive.irreversible_data SET is_dirty = FALSE;
    PERFORM hive.dlog('<no-context>', '"Exiting set_irreversible_not_dirty"');
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
    PERFORM hive.dlog('<no-context>', '"Entering disable_indexes_of_irreversible"');
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'irreversible_data' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'blocks' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'transactions' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'transactions_multisig' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'operations' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'applied_hardforks' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'accounts' );
    PERFORM hive.save_and_drop_indexes_constraints( 'hive', 'account_operations' );
    PERFORM hive.dlog('<no-context>', '"Exiting disable_indexes_of_irreversible"');
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
    PERFORM hive.dlog('<no-context>', '"Entering disable_fk_of_irreversible"');
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'irreversible_data' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'blocks' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'transactions' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'transactions_multisig' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'operations' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'applied_hardforks' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'accounts' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'account_operations' );
    PERFORM hive.save_and_drop_indexes_foreign_keys( 'hive', 'applied_hardforks' );
    PERFORM hive.dlog('<no-context>', '"Exiting disable_fk_of_irreversible"');
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
    PERFORM hive.dlog('<no-context>', '"Entering enable_indexes_of_irreversible"');
    PERFORM hive.restore_indexes( 'hive.blocks' );
    PERFORM hive.restore_indexes( 'hive.transactions' );
    PERFORM hive.restore_indexes( 'hive.transactions_multisig' );
    PERFORM hive.restore_indexes( 'hive.operations' );
    PERFORM hive.restore_indexes( 'hive.applied_hardforks' );
    PERFORM hive.restore_indexes( 'hive.accounts' );
    PERFORM hive.restore_indexes( 'hive.account_operations' );
    PERFORM hive.restore_indexes( 'hive.irreversible_data' );
    PERFORM hive.dlog('<no-context>', '"Exiting enable_indexes_of_irreversible"');
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
    PERFORM hive.dlog('<no-context>', '"Entering enable_fk_of_irreversible"');
    PERFORM hive.restore_foreign_keys( 'hive.blocks' );
    PERFORM hive.restore_foreign_keys( 'hive.transactions' );
    PERFORM hive.restore_foreign_keys( 'hive.transactions_multisig' );
    PERFORM hive.restore_foreign_keys( 'hive.operations' );
    PERFORM hive.restore_foreign_keys( 'hive.applied_hardforks' );
    PERFORM hive.restore_foreign_keys( 'hive.irreversible_data' );
    PERFORM hive.restore_foreign_keys( 'hive.accounts' );
    PERFORM hive.restore_foreign_keys( 'hive.account_operations' );
    PERFORM hive.dlog('<no-context>', '"Exiting enable_fk_of_irreversible"');
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
    PERFORM hive.dlog('<no-context>', '"Entering disable_indexes_of_reversible"');
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
    PERFORM hive.dlog('<no-context>', '"Exiting disable_indexes_of_reversible"');
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
    PERFORM hive.dlog('<no-context>', '"Entering enable_indexes_of_reversible"');
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
<<<<<<< HEAD
<<<<<<< HEAD
    PERFORM hive.restore_foreign_keys( 'hive.applied_hardforks_reversible' );

=======
    PERFORM hive.dlog('<no-context>', 'Exiting enable_indexes_of_reversible');
>>>>>>> Add dlog
=======
    PERFORM hive.dlog('<no-context>', '"Exiting enable_indexes_of_reversible"');
>>>>>>> Add parameter values to dlog
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.connect( _git_sha TEXT, _block_num hive.blocks.num%TYPE )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.dlog('<no-context>', '"Entering connect" _git_sha=%s, _block_num=%s', _git_sha, _block_num::TEXT);
    PERFORM hive.remove_inconsistent_irreversible_data();
    PERFORM hive.back_from_fork( _block_num );
    INSERT INTO hive.hived_connections( block_num, git_sha, time )
    VALUES( _block_num, _git_sha, now() );
    PERFORM hive.dlog('<no-context>', '"Exiting connect" _git_sha=%s, _block_num=%s', _git_sha, _block_num::TEXT);
END;
$BODY$
;
