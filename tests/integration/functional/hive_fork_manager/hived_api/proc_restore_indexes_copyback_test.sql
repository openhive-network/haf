-- hive.proc_restore_indexes of hafd.account_operations with hive.account_operations_copyback = 'copy', as hived
-- runs it: the procedure returns once the table is staged, the ranges are sorted (as hived does on the
-- procedure's connection, here before the copy-back), another session copies the sorted ranges back by
-- COPY ... FREEZE in one transaction (hive.start/end_account_operations_copyback), as hived streams them,
-- and the procedure, CALLed again, builds the indexes without reordering the table again.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    CREATE EXTENSION IF NOT EXISTS pg_visibility;
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible();

    INSERT INTO hafd.account_operations( account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id )
    SELECT ( i * 7919 ) % 97, ( i * 7919 ) % 97, i, i, i % 50 FROM generate_series( 1, 15000 ) i;
    COMMIT;
    INSERT INTO hafd.account_operations( account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id )
    SELECT ( i * 7919 ) % 97, ( i * 7919 ) % 97, i, i, i % 50 FROM generate_series( 15001, 30000 ) i;
    COMMIT;

    CREATE TABLE public.account_operations_before AS SELECT * FROM hafd.account_operations;
    CREATE TABLE public.relation_before AS
    SELECT oid, reltype, relacl::text FROM pg_class WHERE oid = 'hafd.account_operations'::regclass;
    CREATE TABLE public.copyback(
          state_after_stage TEXT
        , state_after_sort TEXT
        , rows_after_sort BIGINT
        , refused_with_index TEXT
        , state_with_index TEXT
        , sorted_tables INTEGER
        , copied BIGINT
        , state_after_copy TEXT
        , pages_after_copy BIGINT
        , not_frozen_pages BIGINT
        , not_frozen_rows BIGINT
    );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __table TEXT;
    __file TEXT;
    __status TEXT;
    __sorted_tables INTEGER := 0;
    __copied BIGINT := 0;
BEGIN
    PERFORM set_config( 'hive.account_operations_copyback', 'copy', FALSE );
    CALL hive.proc_restore_indexes( 'hafd.account_operations' );
    INSERT INTO public.copyback( state_after_stage ) VALUES ( hive.account_operations_copyback_state() );
    COMMIT;
    CALL hive.proc_do_account_operations_reorder_steps( 'sort' );
    UPDATE public.copyback SET
          state_after_sort = hive.account_operations_copyback_state()
        , rows_after_sort = ( SELECT count(*) FROM hafd.account_operations );
    COMMIT;

    -- sorted again in many ranges, so that the copy-back runs a COPY FREEZE for each in its transaction
    CALL hive.proc_stage_and_sort_account_operations( 4 );

    CREATE INDEX account_operations_copyback_test ON hafd.account_operations( account_id );
    UPDATE public.copyback SET state_with_index = hive.account_operations_copyback_state();
    BEGIN
        PERFORM hive.start_account_operations_copyback();
    EXCEPTION WHEN raise_exception THEN
        UPDATE public.copyback SET refused_with_index = SQLERRM;
    END;
    DROP INDEX hafd.account_operations_copyback_test;
    COMMIT;

    -- the server reads the files of the sorted tables in place of hived's stream from another connection
    FOR __table IN
        SELECT format( 'hafd.%I', 'account_operations_reorder_sorted_' || arg ) FROM hafd.account_operations_reorder_steps WHERE kind = 'sort'
    LOOP
        EXECUTE format( 'COPY %s TO %L (FORMAT binary)', __table, '/tmp/haf_copyback_test_' || __table || '.bin' );
    END LOOP;
    -- releases the sorted tables, which the copy-back drops
    COMMIT;

    PERFORM dblink_connect( 'copier', format( 'dbname=%s user=%s port=%s host=%s'
        , current_database(), current_user, current_setting( 'port' )
        , split_part( current_setting( 'unix_socket_directories' ), ',', 1 ) ) );
    PERFORM dblink_exec( 'copier', 'BEGIN' );
    FOR __table IN SELECT t FROM dblink( 'copier', 'SELECT hive.start_account_operations_copyback()' ) AS r( t TEXT ) LOOP
        __file := '/tmp/haf_copyback_test_' || __table || '.bin';
        __status := dblink_exec( 'copier', format( 'COPY hafd.account_operations FROM PROGRAM %L (FORMAT binary, FREEZE)', format( 'cat %1$s && rm %1$s', __file ) ) );
        __copied := __copied + split_part( __status, ' ', 2 )::BIGINT;
        __sorted_tables := __sorted_tables + 1;
    END LOOP;
    PERFORM * FROM dblink( 'copier', format( 'SELECT hive.end_account_operations_copyback( %s )', __copied ) ) AS t( r TEXT );
    PERFORM dblink_exec( 'copier', 'COMMIT' );
    PERFORM dblink_disconnect( 'copier' );

    UPDATE public.copyback SET
          sorted_tables = __sorted_tables
        , copied = __copied
        , state_after_copy = hive.account_operations_copyback_state()
        , pages_after_copy = pg_relation_size( 'hafd.account_operations' ) / current_setting( 'block_size' )::BIGINT
        , not_frozen_pages = ( SELECT count(*) FROM pg_visibility_map( 'hafd.account_operations' ) WHERE NOT all_frozen )
        -- rows on all-frozen pages that are not frozen
        , not_frozen_rows = ( SELECT count(*) FROM pg_check_frozen( 'hafd.account_operations' ) );
    COMMIT;

    CALL hive.proc_restore_indexes( 'hafd.account_operations' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_error()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM set_config( 'hive.account_operations_copyback', 'stream', FALSE );
    PERFORM hive.account_operations_copyback_method();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __copyback RECORD;
BEGIN
    SELECT * INTO __copyback FROM public.copyback;
    ASSERT __copyback.state_after_stage = 'sorting', 'hive.proc_restore_indexes did not leave the sort and the copy-back to its caller';
    ASSERT __copyback.state_after_sort = 'pending', 'The sorted ranges do not await their copy-back';
    ASSERT __copyback.rows_after_sort = 30000, 'hafd.account_operations changed before its copy-back';
    ASSERT __copyback.state_with_index IS NULL, 'A copy-back is pending although hafd.account_operations has an index';
    ASSERT __copyback.refused_with_index LIKE '%has indexes%', 'The copy-back did not refuse to run with an index present';
    ASSERT __copyback.sorted_tables > 1, 'The copy-back did not copy several sorted ranges';
    ASSERT __copyback.copied = 30000, 'The copy-back copied a wrong number of rows';
    ASSERT __copyback.state_after_copy = 'copied', 'The copy-back was not recorded';
    ASSERT __copyback.pages_after_copy > 1, 'hafd.account_operations is too small to check its visibility map';
    ASSERT __copyback.not_frozen_pages = 0, 'COPY FREEZE left pages of hafd.account_operations not all-frozen in the visibility map';
    ASSERT __copyback.not_frozen_rows = 0, 'COPY FREEZE left rows of hafd.account_operations not frozen';

    ASSERT NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints WHERE table_name = 'hafd.account_operations' AND is_foreign_key = FALSE AND status != 'created' ),
        'Not every index of hafd.account_operations was restored';
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
    ASSERT NOT EXISTS(
        SELECT oid, reltype, relacl::text FROM pg_class WHERE oid = 'hafd.account_operations'::regclass
        EXCEPT
        SELECT * FROM public.relation_before
    ), 'hafd.account_operations was replaced or lost its grants';
    ASSERT NOT EXISTS( SELECT 1 FROM pg_class WHERE relnamespace = 'hafd'::regnamespace AND relname LIKE 'account\_operations\_reorder\_%' ),
        'The reorder left its tables behind';
    ASSERT hive.account_operations_copyback_state() IS NULL, 'A copy-back is still recorded after the restore';
    ASSERT ( SELECT count(*) FROM hive.irreversible_account_operations_view ) = 30000,
        'hive.irreversible_account_operations_view does not read the copied table';
END;
$BODY$
;
