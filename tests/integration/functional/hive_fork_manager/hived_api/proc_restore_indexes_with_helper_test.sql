-- hive.proc_restore_indexes of hafd.account_operations with a helper (hive.proc_help_restore_indexes) in
-- another session, as hived runs them: the lock is taken before the helper starts, both share the
-- reorder and the index builds, and the helper returns once every index is restored.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible();

    INSERT INTO hafd.account_operations( account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id )
    SELECT ( i * 7919 ) % 97, ( i * 7919 ) % 97, i, i, i % 50 FROM generate_series( 1, 15000 ) i;
    COMMIT;
    INSERT INTO hafd.account_operations( account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id )
    SELECT ( i * 7919 ) % 97, ( i * 7919 ) % 97, i, i, i % 50 FROM generate_series( 15001, 30000 ) i;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM pg_advisory_lock( hive.index_restore_lock_key( 'hafd.account_operations' ) );
    PERFORM dblink_connect( 'helper', format( 'dbname=%s user=%s port=%s host=%s'
        , current_database(), current_user, current_setting( 'port' )
        , split_part( current_setting( 'unix_socket_directories' ), ',', 1 ) ) );
    PERFORM dblink_send_query( 'helper', 'CALL hive.proc_help_restore_indexes( ''hafd.account_operations'' )' );

    CALL hive.proc_restore_indexes( 'hafd.account_operations' );

    -- raises the helper's error, if it failed
    PERFORM * FROM dblink_get_result( 'helper' ) AS t( status TEXT );
    PERFORM * FROM dblink_get_result( 'helper' ) AS t( status TEXT );
    PERFORM dblink_disconnect( 'helper' );
    PERFORM pg_advisory_unlock( hive.index_restore_lock_key( 'hafd.account_operations' ) );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints WHERE table_name = 'hafd.account_operations' AND is_foreign_key = FALSE AND status != 'created' ),
        'Not every index of hafd.account_operations was restored';
    ASSERT ( SELECT indisclustered FROM pg_index WHERE indexrelid = 'hafd.hive_account_operations_uq1'::regclass ),
        'hafd.account_operations is not marked clustered on hive_account_operations_uq1';
    ASSERT ( SELECT count(*) FROM hafd.account_operations ) = 30000, 'Rows were lost or duplicated';
    ASSERT NOT EXISTS(
        SELECT 1 FROM (
            SELECT account_id, account_op_seq_no
                 , lag( account_id ) OVER w AS prev_account_id, lag( account_op_seq_no ) OVER w AS prev_account_op_seq_no
            FROM hafd.account_operations WINDOW w AS ( ORDER BY ctid )
        ) r
        WHERE ( prev_account_id, prev_account_op_seq_no ) > ( account_id, account_op_seq_no )
    ), 'hafd.account_operations is not physically ordered by (account_id, account_op_seq_no)';
    ASSERT ( SELECT count( DISTINCT xmin::text ) FROM hafd.account_operations ) = 1,
        'hafd.account_operations was not reordered by the rewrite';
    ASSERT NOT EXISTS( SELECT 1 FROM pg_class WHERE relnamespace = 'hafd'::regnamespace AND relname LIKE 'account\_operations\_reorder\_%' ),
        'The reorder left its tables behind';
    ASSERT NOT EXISTS( SELECT 1 FROM pg_locks WHERE locktype = 'advisory' ),
        'An advisory lock of the restore is still held';
END;
$BODY$
;
