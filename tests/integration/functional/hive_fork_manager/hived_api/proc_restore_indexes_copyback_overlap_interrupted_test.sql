-- The restore of hafd.account_operations (hive.account_operations_copyback = 'copy') interrupted in the middle
-- of its chain, as when hived stops: the copy-back has truncated the table and copied the first sorted range
-- while the later ranges are not sorted yet when its session ends. The table is left as it was, and the
-- restore, run again as hived runs it, reorders it anew, copies it back and builds each index once, valid.

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

    CREATE TABLE public.account_operations_before AS SELECT * FROM hafd.account_operations;
    CREATE TABLE public.interrupted(
          filenode_before OID
        , sorted_tables INTEGER
        , copied_before_interruption BIGINT
        , unsorted_at_interruption INTEGER
        , rows_after_interruption BIGINT
        , filenode_after_interruption OID
        , state_after_interruption TEXT
        , state_after_restart TEXT
    );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __tables TEXT[];
    __copier_pid INTEGER;
    __status TEXT;
    __table TEXT;
    __rows BIGINT;
    __copied BIGINT := 0;
    __i INTEGER;
BEGIN
    PERFORM set_config( 'hive.account_operations_copyback', 'copy', FALSE );
    INSERT INTO public.interrupted( filenode_before ) VALUES ( pg_relation_filenode( 'hafd.account_operations' ) );
    COMMIT;

    -- staged in many ranges, as the procedure does with the default slices of a large table
    PERFORM hive.prepare_account_operations_reorder( 4 );
    COMMIT;
    CALL hive.proc_do_account_operations_reorder_steps( 'stage' );

    PERFORM dblink_connect( 'copier', format( 'dbname=%s user=%s port=%s host=%s'
        , current_database(), current_user, current_setting( 'port' )
        , split_part( current_setting( 'unix_socket_directories' ), ',', 1 ) ) );
    __copier_pid := ( SELECT pid FROM dblink( 'copier', 'SELECT pg_backend_pid()' ) AS t( pid INTEGER ) );
    PERFORM dblink_exec( 'copier', 'BEGIN' );
    __tables := ARRAY( SELECT t FROM dblink( 'copier', 'SELECT hive.start_account_operations_copyback()' ) AS r( t TEXT ) );
    PERFORM hive.do_account_operations_reorder_step( 'sort' );
    COMMIT;
    __status := dblink_exec( 'copier', format( 'INSERT INTO hafd.account_operations SELECT * FROM %s', __tables[ 1 ] ) );

    UPDATE public.interrupted SET
          sorted_tables = cardinality( __tables )
        , copied_before_interruption = split_part( __status, ' ', 3 )::BIGINT
        , unsorted_at_interruption = ( SELECT count(*) FROM unnest( __tables ) t WHERE NOT hive.is_account_operations_range_sorted( t ) );
    COMMIT;

    -- hived stops: the copy-back's session ends in the middle of its transaction
    PERFORM pg_terminate_backend( __copier_pid );
    FOR __i IN 1 .. 600 LOOP
        PERFORM pg_stat_clear_snapshot();
        EXIT WHEN NOT EXISTS( SELECT 1 FROM pg_stat_activity WHERE pid = __copier_pid );
        PERFORM pg_sleep( 0.1 );
    END LOOP;
    PERFORM dblink_disconnect( 'copier' );

    UPDATE public.interrupted SET
          rows_after_interruption = ( SELECT count(*) FROM hafd.account_operations )
        , filenode_after_interruption = pg_relation_filenode( 'hafd.account_operations' )
        , state_after_interruption = hive.account_operations_copyback_state();
    COMMIT;

    -- hived restarts: the restore stages the table, sorts it and copies it back again
    CALL hive.proc_restore_indexes( 'hafd.account_operations' );
    UPDATE public.interrupted SET state_after_restart = hive.account_operations_copyback_state();
    COMMIT;
    CALL hive.proc_do_account_operations_reorder_steps( 'sort' );
    -- the copy-back that hived streams by COPY FREEZE, here by INSERT
    FOR __table IN SELECT hive.start_account_operations_copyback() LOOP
        EXECUTE format( 'INSERT INTO hafd.account_operations SELECT * FROM %s', __table );
        GET DIAGNOSTICS __rows = ROW_COUNT;
        __copied := __copied + __rows;
    END LOOP;
    PERFORM hive.end_account_operations_copyback( __copied );
    COMMIT;
    CALL hive.proc_restore_indexes( 'hafd.account_operations' );
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
    ASSERT __interrupted.sorted_tables > 2, 'The table was not staged in several ranges';
    ASSERT __interrupted.copied_before_interruption > 0, 'The copy-back copied nothing before it was interrupted';
    ASSERT __interrupted.unsorted_at_interruption = __interrupted.sorted_tables - 1, 'The copy-back was not interrupted in the middle of the sort';
    ASSERT __interrupted.rows_after_interruption = 30000, 'The interrupted copy-back changed the rows of hafd.account_operations';
    ASSERT __interrupted.filenode_after_interruption = __interrupted.filenode_before, 'The interrupted copy-back replaced hafd.account_operations';
    ASSERT __interrupted.state_after_interruption = 'sorting', 'The interrupted copy-back left a wrong state';
    ASSERT __interrupted.state_after_restart = 'sorting', 'The restarted restore did not stage the table again';

    ASSERT NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints WHERE table_name = 'hafd.account_operations' AND is_foreign_key = FALSE AND status != 'created' ),
        'Not every index of hafd.account_operations was restored';
    ASSERT NOT EXISTS( SELECT 1 FROM pg_index WHERE indrelid = 'hafd.account_operations'::regclass AND NOT ( indisvalid AND indisready ) ),
        'hafd.account_operations has an invalid index';
    ASSERT NOT EXISTS(
        SELECT 1 FROM pg_index WHERE indrelid = 'hafd.account_operations'::regclass
        GROUP BY regexp_replace( pg_get_indexdef( indexrelid ), '^(CREATE (UNIQUE )?INDEX) \S+ ', '\1 ' )
        HAVING count(*) > 1
    ), 'hafd.account_operations has a duplicate index';
    ASSERT ( SELECT count(*) FROM pg_index WHERE indrelid = 'hafd.account_operations'::regclass )
         = ( SELECT count(*) FROM hafd.indexes_constraints
             WHERE table_name = 'hafd.account_operations' AND is_foreign_key = FALSE AND ( is_index OR is_constraint ) ),
        'hafd.account_operations has other indexes than those restored';
    ASSERT ( SELECT indisclustered FROM pg_index WHERE indexrelid = 'hafd.hive_account_operations_uq1'::regclass ),
        'hafd.account_operations is not marked clustered on hive_account_operations_uq1';
    ASSERT NOT EXISTS(
        ( SELECT * FROM public.account_operations_before EXCEPT ALL SELECT * FROM hafd.account_operations )
        UNION ALL
        ( SELECT * FROM hafd.account_operations EXCEPT ALL SELECT * FROM public.account_operations_before )
    ), 'The rows of hafd.account_operations changed';
    ASSERT NOT EXISTS(
        SELECT 1 FROM (
            SELECT account_id, account_op_seq_no
                 , lag( account_id ) OVER w AS prev_account_id, lag( account_op_seq_no ) OVER w AS prev_account_op_seq_no
            FROM hafd.account_operations WINDOW w AS ( ORDER BY ctid )
        ) r
        WHERE ( prev_account_id, prev_account_op_seq_no ) > ( account_id, account_op_seq_no )
    ), 'hafd.account_operations is not physically ordered by (account_id, account_op_seq_no)';
    ASSERT NOT EXISTS( SELECT 1 FROM pg_class WHERE relnamespace = 'hafd'::regnamespace AND relname LIKE 'account\_operations\_reorder\_%' ),
        'The reorder left its tables behind';
END;
$BODY$
;
