CREATE OR REPLACE FUNCTION public.deferred_by( _index TEXT, _head_distance INTEGER = 1000, _max_deferral INTERVAL = '6 hours' )
    RETURNS TEXT[]
    LANGUAGE sql
    STABLE
AS
$BODY$
    SELECT deferred_by FROM hive.missing_index_builds( _head_distance, _max_deferral ) WHERE index_constraint_name = _index;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- 10000 is the irreversible head
    INSERT INTO hafd.blocks
    VALUES
        ( 10000, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;
    INSERT INTO hafd.accounts( id, name, block_num ) VALUES ( 5, 'initminer', 10000 );
    UPDATE hafd.hive_state SET consistent_block = 10000;

    CREATE SCHEMA test_app;
    PERFORM hive.app_create_context( _name => 'registering_ctx', _schema => 'test_app' );
    PERFORM hive.app_create_context( _name => 'syncing_ctx', _schema => 'test_app' );
    PERFORM hive.register_index_dependency( 'registering_ctx', 'CREATE INDEX test_operations_trx_in_block_idx ON hafd.operations ( trx_in_block )' );
    PERFORM hive.register_index_dependency( 'registering_ctx', 'CREATE INDEX test_blocks_signing_key_idx ON hafd.blocks ( signing_key )' );
    CREATE TABLE test_app.own_table( id INTEGER );
    PERFORM hive.register_index_dependency( 'registering_ctx', 'CREATE INDEX test_own_table_id_idx ON test_app.own_table ( id )' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT array_agg( index_constraint_name ORDER BY index_constraint_name ) FROM hive.missing_index_builds( 1000, '6 hours' ) )
        = ARRAY[ 'test_blocks_signing_key_idx', 'test_operations_trx_in_block_idx' ]
        , 'Not exactly the missing indexes of HAF tables are selected';
    ASSERT deferred_by( 'test_operations_trx_in_block_idx' ) IS NULL, 'Deferred while no context has a stage';

    -- a massive-sync stage far from the irreversible head
    UPDATE hafd.contexts SET loop.current_stage = hive.stage( 'massive', 100, 1000 ), current_block_num = 8999 WHERE name = 'syncing_ctx';
    ASSERT deferred_by( 'test_operations_trx_in_block_idx' ) IS NULL, 'Deferred by a context in massive sync far from the head';

    -- the same stage within the distance: the context is finalizing
    UPDATE hafd.contexts SET current_block_num = 9000 WHERE name = 'syncing_ctx';
    ASSERT deferred_by( 'test_operations_trx_in_block_idx' ) = ARRAY[ 'syncing_ctx' ], 'Not deferred by a context in massive sync near the head';
    ASSERT deferred_by( 'test_blocks_signing_key_idx' ) = ARRAY[ 'syncing_ctx' ], 'A build on another table is not deferred';
    ASSERT deferred_by( 'test_operations_trx_in_block_idx', 999 ) IS NULL, 'The head distance is not configurable';

    -- the deferral ends when the stage leaves massive sync
    UPDATE hafd.contexts SET loop.current_stage = hafd.live_stage() WHERE name = 'syncing_ctx';
    ASSERT deferred_by( 'test_operations_trx_in_block_idx' ) IS NULL, 'Deferred by a context in the live stage';
    UPDATE hafd.contexts SET loop.current_stage = hafd.wait_for_haf_stage() WHERE name = 'syncing_ctx';
    ASSERT deferred_by( 'test_operations_trx_in_block_idx' ) IS NULL, 'Deferred by a context waiting for HAF';

    -- a flagged context defers the builds only while attached
    PERFORM hive.app_set_finalizing( ARRAY[ 'registering_ctx' ] );
    ASSERT deferred_by( 'test_operations_trx_in_block_idx' ) = ARRAY[ 'registering_ctx' ], 'Not deferred by a flagged context';
    UPDATE hafd.contexts_attachment SET is_attached = FALSE WHERE context_id = ( SELECT id FROM hafd.contexts WHERE name = 'registering_ctx' );
    ASSERT deferred_by( 'test_operations_trx_in_block_idx' ) IS NULL, 'Deferred by a detached context';
    UPDATE hafd.contexts_attachment SET is_attached = TRUE WHERE context_id = ( SELECT id FROM hafd.contexts WHERE name = 'registering_ctx' );

    -- all the finalizing contexts are named
    UPDATE hafd.contexts SET loop.current_stage = hive.stage( 'massive', 100, 1000 ) WHERE name = 'syncing_ctx';
    ASSERT deferred_by( 'test_operations_trx_in_block_idx' ) = ARRAY[ 'registering_ctx', 'syncing_ctx' ], 'Not every finalizing context is named';

    -- the cap counts from the registration
    UPDATE hafd.indexes_constraints SET registered_at = now() - interval '7 hours' WHERE index_constraint_name = 'test_operations_trx_in_block_idx';
    ASSERT deferred_by( 'test_operations_trx_in_block_idx' ) IS NULL, 'Still deferred after the cap';
    ASSERT deferred_by( 'test_blocks_signing_key_idx' ) IS NOT NULL, 'The cap of one index released another';
    ASSERT deferred_by( 'test_operations_trx_in_block_idx', 1000, '8 hours' ) IS NOT NULL, 'The cap is not configurable';

    -- a table with a build in progress is left out
    UPDATE hafd.indexes_constraints SET status = 'creating' WHERE index_constraint_name = 'test_blocks_signing_key_idx';
    PERFORM hive.register_index_dependency( 'registering_ctx', 'CREATE INDEX test_blocks_hash_idx ON hafd.blocks ( hash )' );
    ASSERT NOT EXISTS ( SELECT 1 FROM hive.missing_index_builds( 1000, '6 hours' ) WHERE table_name = 'hafd.blocks' )
        , 'A table with a build in progress is selected';
END;
$BODY$
;
