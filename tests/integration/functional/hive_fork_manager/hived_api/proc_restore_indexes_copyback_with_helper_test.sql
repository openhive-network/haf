-- hive.proc_restore_indexes of hafd.account_operations after the copy-back (hive.account_operations_copyback
-- = 'copy'), as hived runs it, with a helper (hive.proc_help_restore_indexes) in another session: while the
-- restore builds hive_account_operations_uq1, held up by this session's lock on its hafd.indexes_constraints
-- row, the helper is not blocked on the reorder's steps and builds the table's plain index alongside it.

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

    CREATE TABLE public.during_uq1(
          helper_waited_on_steps BOOLEAN
        , plain_index_status TEXT
        , uq1_status TEXT
        , restorer_busy BOOLEAN
        , not_null_restored BIGINT
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
    __table TEXT;
    __rows BIGINT;
    __copied BIGINT := 0;
    __restorer_pid INTEGER;
    __helper_pid INTEGER;
    __waited_on_steps BOOLEAN := FALSE;
    __i INTEGER;
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

    PERFORM dblink_connect( 'restorer', __connection );
    PERFORM dblink_connect( 'helper', __connection );
    __restorer_pid := ( SELECT pid FROM dblink( 'restorer', 'SELECT pg_backend_pid()' ) AS t( pid INTEGER ) );
    __helper_pid := ( SELECT pid FROM dblink( 'helper', 'SELECT pg_backend_pid()' ) AS t( pid INTEGER ) );

    -- holds up the restore's build of hive_account_operations_uq1 until this transaction ends
    PERFORM 1 FROM hafd.indexes_constraints
    WHERE table_name = 'hafd.account_operations' AND index_constraint_name = 'hive_account_operations_uq1' FOR UPDATE;
    PERFORM dblink_send_query( 'restorer', 'CALL hive.proc_restore_indexes( ''hafd.account_operations'' )' );
    FOR __i IN 1 .. 600 LOOP
        EXIT WHEN pg_backend_pid() = ANY( pg_blocking_pids( __restorer_pid ) ) OR dblink_is_busy( 'restorer' ) = 0;
        PERFORM pg_sleep( 0.1 );
    END LOOP;
    -- started once the restore holds hive.index_restore_lock_key, as hived does
    PERFORM dblink_send_query( 'helper', 'CALL hive.proc_help_restore_indexes( ''hafd.account_operations'' )' );

    -- samples the helper for a while after it built the plain index, as it goes on reading the steps
    FOR __i IN 1 .. 600 LOOP
        __waited_on_steps := __waited_on_steps OR EXISTS(
            SELECT 1 FROM pg_locks l JOIN pg_class c ON c.oid = l.relation
            WHERE l.pid = __helper_pid AND NOT l.granted
              AND c.relnamespace = 'hafd'::regnamespace AND c.relname LIKE 'account\_operations\_reorder\_%' );
        EXIT WHEN __waited_on_steps OR dblink_is_busy( 'restorer' ) = 0 OR dblink_is_busy( 'helper' ) = 0;
        EXIT WHEN __i > 30 AND EXISTS( SELECT 1 FROM hafd.indexes_constraints
                                       WHERE index_constraint_name = 'hive_account_operations_account_id_op_type_id_idx' AND status = 'created' );
        PERFORM pg_sleep( 0.1 );
    END LOOP;

    INSERT INTO public.during_uq1
    SELECT __waited_on_steps
         , ( SELECT status FROM hafd.indexes_constraints WHERE index_constraint_name = 'hive_account_operations_account_id_op_type_id_idx' )
         , ( SELECT status FROM hafd.indexes_constraints WHERE index_constraint_name = 'hive_account_operations_uq1' )
         , dblink_is_busy( 'restorer' ) = 1
         , ( SELECT count(*) FROM hafd.indexes_constraints
             WHERE table_name = 'hafd.account_operations' AND NOT is_constraint AND NOT is_index AND NOT is_foreign_key AND status <> 'missing' );
    COMMIT;

    -- raise the restore's or the helper's error, if it failed
    PERFORM * FROM dblink_get_result( 'restorer' ) AS t( status TEXT );
    PERFORM * FROM dblink_get_result( 'restorer' ) AS t( status TEXT );
    PERFORM * FROM dblink_get_result( 'helper' ) AS t( status TEXT );
    PERFORM * FROM dblink_get_result( 'helper' ) AS t( status TEXT );
    PERFORM dblink_disconnect( 'restorer' );
    PERFORM dblink_disconnect( 'helper' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __during RECORD;
BEGIN
    SELECT * INTO __during FROM public.during_uq1;
    ASSERT __during.restorer_busy, 'The restore ended before hive_account_operations_uq1 was let through';
    ASSERT __during.uq1_status = 'missing', 'hive_account_operations_uq1 committed while it was held up';
    ASSERT NOT __during.helper_waited_on_steps, 'The helper waited on the reorder''s steps while hive_account_operations_uq1 was built';
    ASSERT __during.plain_index_status = 'created', 'The helper did not build the plain index alongside hive_account_operations_uq1';
    ASSERT __during.not_null_restored = 0, 'The NOT NULL constraints were restored while hive_account_operations_uq1 was built';

    ASSERT NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints WHERE table_name = 'hafd.account_operations' AND is_foreign_key = FALSE AND status != 'created' ),
        'Not every index of hafd.account_operations was restored';
    ASSERT ( SELECT indisclustered FROM pg_index WHERE indexrelid = 'hafd.hive_account_operations_uq1'::regclass ),
        'hafd.account_operations is not marked clustered on hive_account_operations_uq1';
    ASSERT ( SELECT count(*) FROM hafd.account_operations ) = 30000, 'Rows were lost or duplicated';
    ASSERT NOT EXISTS( SELECT 1 FROM pg_class WHERE relnamespace = 'hafd'::regnamespace AND relname LIKE 'account\_operations\_reorder\_%' ),
        'The reorder left its tables behind';
END;
$BODY$
;
