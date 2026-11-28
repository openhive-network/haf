-- While the restore of hafd.account_operations holds its lock and has not built hive_account_operations_uq1
-- (hive.is_account_operations_reorder_running), the index builds of another table are capped across its
-- sessions (hive.claim_index_build_slot): one at a time by default, as many as
-- hive.index_builds_beside_account_operations_reorder says, none with '0'; hafd.account_operations' own
-- builds are not capped, and neither is any build once the restore releases its lock. A restore of
-- hafd.operations still completes beside the reorder, one build at a time.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible();

    CREATE TABLE public.slots(
          running_before_lock BOOLEAN
        , running_with_lock BOOLEAN
        , running_with_uq1 BOOLEAN
        , first_build BOOLEAN
        , second_build BOOLEAN
        , other_table_build BOOLEAN
        , account_operations_build BOOLEAN
        , next_index_beside_build BOOLEAN
        , operations_built_beside_build BIGINT
        , second_build_of_two BOOLEAN
        , other_table_build_of_none BOOLEAN
        , build_of_none_after_lock BOOLEAN
        , operations_missing BIGINT
    );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __connection TEXT := format( 'dbname=%s user=%s port=%s host=%s'
        , current_database(), current_user, current_setting( 'port' )
        , split_part( current_setting( 'unix_socket_directories' ), ',', 1 ) );
BEGIN
    INSERT INTO public.slots( running_before_lock ) VALUES ( hive.is_account_operations_reorder_running() );
    COMMIT;

    PERFORM dblink_connect( 'restorer', __connection );
    PERFORM dblink_connect( 'builder1', __connection );
    PERFORM dblink_connect( 'builder2', __connection );
    -- as hived's restore of hafd.account_operations holds it
    PERFORM * FROM dblink( 'restorer', 'SELECT pg_advisory_lock( hive.index_restore_lock_key( ''hafd.account_operations'' ) )' ) AS t( r TEXT );
    UPDATE public.slots SET running_with_lock = hive.is_account_operations_reorder_running();
    UPDATE hafd.indexes_constraints SET status = 'created'
    WHERE table_name = 'hafd.account_operations' AND index_constraint_name = 'hive_account_operations_uq1';
    UPDATE public.slots SET running_with_uq1 = hive.is_account_operations_reorder_running();
    UPDATE hafd.indexes_constraints SET status = 'missing'
    WHERE table_name = 'hafd.account_operations' AND index_constraint_name = 'hive_account_operations_uq1';
    COMMIT;

    -- builder1 holds the only slot of hafd.operations until its transaction ends
    PERFORM dblink_exec( 'builder1', 'BEGIN' );
    UPDATE public.slots SET
          first_build = ( SELECT r FROM dblink( 'builder1', 'SELECT hive.claim_index_build_slot( ''hafd.operations'' )' ) AS t( r BOOLEAN ) )
        , second_build = ( SELECT r FROM dblink( 'builder2', 'SELECT hive.claim_index_build_slot( ''hafd.operations'' )' ) AS t( r BOOLEAN ) )
        , other_table_build = ( SELECT r FROM dblink( 'builder2', 'SELECT hive.claim_index_build_slot( ''hafd.blocks'' )' ) AS t( r BOOLEAN ) )
        , account_operations_build = ( SELECT r FROM dblink( 'builder2', 'SELECT hive.claim_index_build_slot( ''hafd.account_operations'' )' ) AS t( r BOOLEAN ) )
        , next_index_beside_build = ( SELECT r FROM dblink( 'builder2', 'SELECT hive.restore_next_index( ''hafd.operations'' )' ) AS t( r BOOLEAN ) );
    UPDATE public.slots SET operations_built_beside_build = (
        SELECT count(*) FROM hafd.indexes_constraints WHERE table_name = 'hafd.operations' AND is_foreign_key = FALSE AND status <> 'missing' );
    COMMIT;

    PERFORM dblink_exec( 'builder2', 'SET hive.index_builds_beside_account_operations_reorder = ''2''' );
    UPDATE public.slots SET
        second_build_of_two = ( SELECT r FROM dblink( 'builder2', 'SELECT hive.claim_index_build_slot( ''hafd.operations'' )' ) AS t( r BOOLEAN ) );
    PERFORM dblink_exec( 'builder2', 'SET hive.index_builds_beside_account_operations_reorder = ''0''' );
    UPDATE public.slots SET
        other_table_build_of_none = ( SELECT r FROM dblink( 'builder2', 'SELECT hive.claim_index_build_slot( ''hafd.blocks'' )' ) AS t( r BOOLEAN ) );
    PERFORM dblink_exec( 'builder1', 'COMMIT' );
    COMMIT;

    -- beside the reorder, the restore of hafd.operations builds its indexes one after another
    CALL hive.proc_restore_indexes( 'hafd.operations' );
    UPDATE public.slots SET operations_missing = (
        SELECT count(*) FROM hafd.indexes_constraints WHERE table_name = 'hafd.operations' AND is_foreign_key = FALSE AND status <> 'created' );
    COMMIT;

    PERFORM * FROM dblink( 'restorer', 'SELECT pg_advisory_unlock( hive.index_restore_lock_key( ''hafd.account_operations'' ) )' ) AS t( r TEXT );
    UPDATE public.slots SET
        build_of_none_after_lock = ( SELECT r FROM dblink( 'builder2', 'SELECT hive.claim_index_build_slot( ''hafd.blocks'' )' ) AS t( r BOOLEAN ) );
    COMMIT;

    PERFORM dblink_disconnect( 'restorer' );
    PERFORM dblink_disconnect( 'builder1' );
    PERFORM dblink_disconnect( 'builder2' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_error()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM set_config( 'hive.index_builds_beside_account_operations_reorder', 'many', FALSE );
    PERFORM hive.index_builds_beside_account_operations_reorder();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __slots RECORD;
BEGIN
    SELECT * INTO __slots FROM public.slots;
    ASSERT NOT __slots.running_before_lock, 'The reorder runs without the restore of hafd.account_operations';
    ASSERT __slots.running_with_lock, 'The reorder does not run while the restore of hafd.account_operations holds its lock';
    ASSERT NOT __slots.running_with_uq1, 'The reorder still runs once hive_account_operations_uq1 is built';
    ASSERT __slots.first_build, 'The first build of hafd.operations was held back';
    ASSERT NOT __slots.second_build, 'A second build of hafd.operations was let beside the reorder';
    ASSERT __slots.other_table_build, 'The build of another table was held back by those of hafd.operations';
    ASSERT __slots.account_operations_build, 'A build of hafd.account_operations was held back';
    ASSERT NOT __slots.next_index_beside_build, 'hive.restore_next_index built an index of hafd.operations without a slot';
    ASSERT __slots.operations_built_beside_build = 0, 'An index of hafd.operations was built without a slot';
    ASSERT __slots.second_build_of_two, 'hive.index_builds_beside_account_operations_reorder is not obeyed';
    ASSERT NOT __slots.other_table_build_of_none, 'A build was let beside the reorder with hive.index_builds_beside_account_operations_reorder = 0';
    ASSERT __slots.build_of_none_after_lock, 'A build was held back after the restore of hafd.account_operations released its lock';
    ASSERT __slots.operations_missing = 0, 'The restore of hafd.operations did not build every index beside the reorder';
END;
$BODY$
;
