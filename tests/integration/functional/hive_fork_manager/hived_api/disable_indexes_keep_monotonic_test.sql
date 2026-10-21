CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES ( 1, 'hive::protocol::vote_operation', FALSE )
         , ( 2, 'hive::protocol::comment_operation', FALSE );
    -- an index an app created directly on a hafd table, keyed by block number
    PERFORM hive.create_op_type_partial_index( ARRAY[ 1, 2 ]::SMALLINT[] );
    PERFORM hive.disable_fk_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.disable_indexes_of_irreversible( 'keep-monotonic' );
END;
$BODY$
;

DROP FUNCTION IF EXISTS index_or_constraint_exists;
CREATE FUNCTION index_or_constraint_exists( _table_name TEXT, _name TEXT )
    RETURNS bool
    LANGUAGE 'sql'
AS
$BODY$
    SELECT EXISTS( SELECT 1 FROM pg_indexes WHERE schemaname || '.' || tablename = _table_name AND indexname = _name )
        OR EXISTS( SELECT 1 FROM pg_constraint WHERE conrelid = _table_name::regclass AND conname = _name );
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __row RECORD;
BEGIN
    ASSERT NOT EXISTS(
        SELECT 1 FROM hafd.indexes_constraints
        WHERE table_name IN ( 'hafd.blocks', 'hafd.transactions', 'hafd.transactions_multisig', 'hafd.operations'
                            , 'hafd.applied_hardforks', 'hafd.accounts', 'hafd.account_operations' )
          AND ( is_index OR is_constraint ) AND massive_sync_class IS NULL
    ), 'A core index of the irreversible tables was saved without a massive sync class';

    ASSERT ( SELECT array_agg( index_constraint_name ORDER BY index_constraint_name COLLATE "C" ) FROM hafd.indexes_constraints WHERE massive_sync_class = 'keep' )
        = ARRAY[
              'hive_accounts_block_num_idx'
            , 'hive_applied_hardforks_block_num_idx'
            , 'hive_blocks_created_at_idx'
            , 'hive_operations_block_num_id_idx'
            , 'hive_operations_block_num_trx_in_block_idx'
            , 'hive_operations_op_types_1_2_idx'
            , 'hive_transactions_block_num_trx_in_block_idx'
            , 'pk_hive_accounts_id'
            , 'pk_hive_applied_hardforks'
            , 'pk_hive_blocks'
            , 'pk_hive_operations'
            , 'uq_hive_accounst_name'
          ], FORMAT( 'Unexpected set of kept indexes: %s', ( SELECT array_agg( index_constraint_name ) FROM hafd.indexes_constraints WHERE massive_sync_class = 'keep' ) );

    FOR __row IN SELECT * FROM hafd.indexes_constraints WHERE massive_sync_class = 'keep' LOOP
        ASSERT __row.status = 'created', FORMAT( 'Kept index %s has status %s', __row.index_constraint_name, __row.status );
        ASSERT index_or_constraint_exists( __row.table_name, __row.index_constraint_name ), FORMAT( 'Kept index %s was dropped', __row.index_constraint_name );
    END LOOP;

    FOR __row IN SELECT * FROM hafd.indexes_constraints WHERE massive_sync_class = 'defer' LOOP
        ASSERT __row.status = 'missing', FORMAT( 'Deferred index %s has status %s', __row.index_constraint_name, __row.status );
        ASSERT NOT index_or_constraint_exists( __row.table_name, __row.index_constraint_name ), FORMAT( 'Deferred index %s was not dropped', __row.index_constraint_name );
    END LOOP;

    ASSERT ( SELECT massive_sync_class FROM hafd.indexes_constraints WHERE index_constraint_name = 'pk_hive_transactions' ) = 'defer', 'pk_hive_transactions is not deferred';
    ASSERT ( SELECT massive_sync_class FROM hafd.indexes_constraints WHERE index_constraint_name = 'hive_account_operations_uq1' ) = 'defer', 'hive_account_operations_uq1 is not deferred';
    ASSERT ( SELECT massive_sync_class FROM hafd.indexes_constraints WHERE index_constraint_name = 'hive_operations_op_type_id_block_num' ) = 'defer', 'hive_operations_op_type_id_block_num is not deferred';

    -- apps look accounts up by name and id while hived replays
    ASSERT hive.are_core_indexes_created( 'hafd.accounts', 'pk_hive_accounts_id' ), 'pk_hive_accounts_id is reported missing';
    ASSERT hive.are_core_indexes_created( 'hafd.accounts', 'uq_hive_accounst_name' ), 'uq_hive_accounst_name is reported missing';
    ASSERT hive.are_core_indexes_created( 'hafd.accounts', 'hive_accounts_block_num_idx' ), 'hive_accounts_block_num_idx is reported missing';
    ASSERT EXISTS( SELECT 1 FROM pg_constraint WHERE conrelid = 'hafd.accounts'::regclass AND conname = 'uq_hive_accounst_name' AND contype = 'u' )
         , 'uq_hive_accounst_name is not a unique constraint any more';

    -- foreign keys are dropped as with drop-all
    ASSERT NOT EXISTS(
        SELECT 1 FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace
        WHERE n.nspname = 'hafd' AND c.contype = 'f'
          AND c.conrelid::regclass::text IN ( 'hafd.blocks', 'hafd.transactions', 'hafd.transactions_multisig', 'hafd.operations'
                                            , 'hafd.applied_hardforks', 'hafd.accounts', 'hafd.account_operations', 'hafd.hive_state' )
    ), 'A foreign key of the irreversible tables still exists';

    ASSERT NOT hive.is_instance_ready(), 'is_instance_ready() must stay false while deferred indexes are missing';
    ASSERT hive.is_instance_ready_for_block_processing(), 'is_instance_ready_for_block_processing() must hold once the kept indexes exist';

    ASSERT hive.are_core_indexes_created( 'hafd.operations', 'pk_hive_operations' ), 'pk_hive_operations is reported missing';
    ASSERT NOT hive.are_core_indexes_created( 'hafd.account_operations', 'hive_account_operations_uq1' ), 'hive_account_operations_uq1 is reported created';
    ASSERT NOT hive.are_core_indexes_created( 'hafd.operations' ), 'hafd.operations is reported complete';
END;
$BODY$
;
