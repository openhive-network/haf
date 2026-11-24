-- hive.proc_restore_indexes of hafd.account_operations after the copy-back (hive.account_operations_copyback
-- = 'copy'), interrupted (lock_timeout on a lock this session holds) first before hive_account_operations_uq1
-- commits, then after it commits but before the reorder's tables are dropped: CALLed again each time, it
-- does not reorder the table again, and at last restores every index and leaves no reorder table behind.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible();

    INSERT INTO hafd.account_operations( account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id )
    SELECT ( i * 7919 ) % 97, ( i * 7919 ) % 97, i, i, i % 50 FROM generate_series( 1, 30000 ) i;
    COMMIT;

    CREATE TABLE public.interrupted(
          filenode_after_copy OID
        , first_call TEXT
        , steps_changed BOOLEAN
        , uq1_after_first TEXT
        , second_call TEXT
        , uq1_after_second TEXT
        , steps_after_second BOOLEAN
        , filenode_after_restore OID
    );
    CREATE TABLE public.steps_after_copy( kind TEXT, arg BIGINT, pages BIGINT, rows BIGINT, done BOOLEAN );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __table TEXT;
    __rows BIGINT;
    __copied BIGINT := 0;
BEGIN
    PERFORM set_config( 'hive.account_operations_copyback', 'copy', FALSE );
    CALL hive.proc_restore_indexes( 'hafd.account_operations' );
    ASSERT hive.account_operations_copyback_state() = 'pending', 'hive.proc_restore_indexes did not leave the copy-back to its caller';
    COMMIT;

    -- the copy-back that hived streams by COPY FREEZE, here by INSERT
    FOR __table IN SELECT hive.start_account_operations_copyback() LOOP
        EXECUTE format( 'INSERT INTO hafd.account_operations SELECT * FROM %s', __table );
        GET DIAGNOSTICS __rows = ROW_COUNT;
        __copied := __copied + __rows;
    END LOOP;
    PERFORM hive.end_account_operations_copyback( __copied );
    COMMIT;

    INSERT INTO public.steps_after_copy SELECT kind, arg, pages, rows, done FROM hafd.account_operations_reorder_steps;
    INSERT INTO public.interrupted( filenode_after_copy ) VALUES ( pg_relation_filenode( 'hafd.account_operations' ) );
    COMMIT;

    PERFORM dblink_connect( 'restorer', format( 'dbname=%s user=%s port=%s host=%s'
        , current_database(), current_user, current_setting( 'port' )
        , split_part( current_setting( 'unix_socket_directories' ), ',', 1 ) ) );
    PERFORM dblink_exec( 'restorer', 'SET lock_timeout = ''2s''' );

    -- interrupted before hive_account_operations_uq1 commits: its build cannot mark it 'creating'
    PERFORM 1 FROM hafd.indexes_constraints
    WHERE table_name = 'hafd.account_operations' AND index_constraint_name = 'hive_account_operations_uq1' FOR UPDATE;
    UPDATE public.interrupted SET first_call = dblink_exec( 'restorer', 'CALL hive.proc_restore_indexes( ''hafd.account_operations'' )', FALSE );
    COMMIT;
    UPDATE public.interrupted SET
          steps_changed = EXISTS(
              ( SELECT kind, arg, pages, rows, done FROM hafd.account_operations_reorder_steps EXCEPT ALL SELECT * FROM public.steps_after_copy )
              UNION ALL
              ( SELECT * FROM public.steps_after_copy EXCEPT ALL SELECT kind, arg, pages, rows, done FROM hafd.account_operations_reorder_steps ) )
        , uq1_after_first = ( SELECT status FROM hafd.indexes_constraints WHERE index_constraint_name = 'hive_account_operations_uq1' );
    COMMIT;

    -- interrupted after hive_account_operations_uq1 commits: the reorder's steps cannot be dropped
    LOCK TABLE hafd.account_operations_reorder_steps IN ACCESS SHARE MODE;
    UPDATE public.interrupted SET second_call = dblink_exec( 'restorer', 'CALL hive.proc_restore_indexes( ''hafd.account_operations'' )', FALSE );
    COMMIT;
    UPDATE public.interrupted SET
          uq1_after_second = ( SELECT status FROM hafd.indexes_constraints WHERE index_constraint_name = 'hive_account_operations_uq1' )
        , steps_after_second = EXISTS( SELECT 1 FROM pg_class WHERE relnamespace = 'hafd'::regnamespace AND relname = 'account_operations_reorder_steps' );
    COMMIT;

    PERFORM dblink_exec( 'restorer', 'CALL hive.proc_restore_indexes( ''hafd.account_operations'' )' );
    PERFORM dblink_disconnect( 'restorer' );
    UPDATE public.interrupted SET filenode_after_restore = pg_relation_filenode( 'hafd.account_operations' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __interrupted RECORD;
BEGIN
    SELECT * INTO __interrupted FROM public.interrupted;
    ASSERT __interrupted.first_call = 'ERROR', 'The restore was not interrupted before hive_account_operations_uq1 committed';
    ASSERT __interrupted.uq1_after_first = 'missing', 'hive_account_operations_uq1 is not missing after the first interruption';
    ASSERT NOT __interrupted.steps_changed, 'The reorder''s steps changed with the first interruption';
    ASSERT __interrupted.second_call = 'ERROR', 'The restore was not interrupted before the reorder''s tables were dropped';
    ASSERT __interrupted.uq1_after_second = 'created', 'hive_account_operations_uq1 did not commit before the second interruption';
    ASSERT __interrupted.steps_after_second, 'The reorder''s steps were dropped with hive_account_operations_uq1';
    ASSERT __interrupted.filenode_after_restore = __interrupted.filenode_after_copy, 'hafd.account_operations was reordered again';

    ASSERT NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints WHERE table_name = 'hafd.account_operations' AND is_foreign_key = FALSE AND status != 'created' ),
        'Not every index of hafd.account_operations was restored';
    ASSERT ( SELECT indisclustered FROM pg_index WHERE indexrelid = 'hafd.hive_account_operations_uq1'::regclass ),
        'hafd.account_operations is not marked clustered on hive_account_operations_uq1';
    ASSERT ( SELECT count(*) FROM hafd.account_operations ) = 30000, 'Rows were lost or duplicated';
    ASSERT NOT EXISTS( SELECT 1 FROM pg_class WHERE relnamespace = 'hafd'::regnamespace AND relname LIKE 'account\_operations\_reorder\_%' ),
        'The reorder left its tables behind';
    ASSERT hive.account_operations_copyback_state() IS NULL, 'A copy-back is still recorded after the restore';
END;
$BODY$
;
