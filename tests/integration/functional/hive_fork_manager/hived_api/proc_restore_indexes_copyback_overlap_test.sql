-- The copy-back of hafd.account_operations (hive.account_operations_copyback = 'copy') overlapping its sort,
-- as hived runs it: once the procedure has staged the table, another session truncates it and, in that one
-- transaction, streams each range by COPY ... FREEZE as soon as it is sorted (hive.is_account_operations_range_sorted),
-- while this session sorts the later ranges beside it, not blocked by the copy-back's lock on the table.
-- The procedure, CALLed again, builds the indexes on the ordered, frozen table without reordering it again.

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
    CREATE TABLE public.overlap(
          state_after_stage TEXT
        , refused_before_stage TEXT
        , state_after_restage TEXT
        , sorted_tables INTEGER
        , unsorted_at_copyback_start INTEGER
        , copied_before_sorted INTEGER
        , later_sorted_before_copy INTEGER
        , copied BIGINT
        , state_after_copy TEXT
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
    __tables TEXT[];
    __i INTEGER;
    __file TEXT;
    __status TEXT;
    __copied BIGINT := 0;
    __copied_before_sorted INTEGER := 0;
    __later_sorted_before_copy INTEGER := 0;
BEGIN
    PERFORM set_config( 'hive.account_operations_copyback', 'copy', FALSE );
    CALL hive.proc_restore_indexes( 'hafd.account_operations' );
    INSERT INTO public.overlap( state_after_stage ) VALUES ( hive.account_operations_copyback_state() );
    COMMIT;

    PERFORM dblink_connect( 'copier', format( 'dbname=%s user=%s port=%s host=%s'
        , current_database(), current_user, current_setting( 'port' )
        , split_part( current_setting( 'unix_socket_directories' ), ',', 1 ) ) );

    -- staged again in many ranges, the copy-back refused until every slice is staged
    PERFORM hive.prepare_account_operations_reorder( 4 );
    COMMIT;
    UPDATE public.overlap SET refused_before_stage = dblink_exec( 'copier', 'SELECT hive.start_account_operations_copyback()', FALSE );
    COMMIT;
    CALL hive.proc_do_account_operations_reorder_steps( 'stage' );
    UPDATE public.overlap SET state_after_restage = hive.account_operations_copyback_state();
    COMMIT;

    PERFORM dblink_exec( 'copier', 'BEGIN' );
    __tables := ARRAY( SELECT t FROM dblink( 'copier', 'SELECT hive.start_account_operations_copyback()' ) AS r( t TEXT ) );
    UPDATE public.overlap SET
          sorted_tables = cardinality( __tables )
        , unsorted_at_copyback_start = ( SELECT count(*) FROM unnest( __tables ) t WHERE NOT hive.is_account_operations_range_sorted( t ) );
    COMMIT;

    -- fails instead of waiting should the sort or the reads here wait for the copy-back's lock
    PERFORM set_config( 'lock_timeout', '10s', FALSE );
    FOR __i IN 1 .. cardinality( __tables ) LOOP
        IF hive.is_account_operations_range_sorted( __tables[ __i ] ) THEN
            __copied_before_sorted := __copied_before_sorted + 1;
        END IF;
        PERFORM hive.do_account_operations_reorder_step( 'sort' );
        COMMIT;
        IF __i < cardinality( __tables ) AND hive.is_account_operations_range_sorted( __tables[ __i + 1 ] ) THEN
            __later_sorted_before_copy := __later_sorted_before_copy + 1;
        END IF;

        -- the server reads the file of the sorted table in place of hived's stream from another connection
        __file := '/tmp/haf_copyback_overlap_test_' || __i || '.bin';
        EXECUTE format( 'COPY %s TO %L (FORMAT binary)', __tables[ __i ], __file );
        -- releases the sorted table, which the copy-back drops
        COMMIT;
        __status := dblink_exec( 'copier', format( 'COPY hafd.account_operations FROM PROGRAM %L (FORMAT binary, FREEZE)', format( 'cat %1$s && rm %1$s', __file ) ) );
        __copied := __copied + split_part( __status, ' ', 2 )::BIGINT;
    END LOOP;
    PERFORM set_config( 'lock_timeout', '0', FALSE );

    PERFORM * FROM dblink( 'copier', format( 'SELECT hive.end_account_operations_copyback( %s )', __copied ) ) AS t( r TEXT );
    PERFORM dblink_exec( 'copier', 'COMMIT' );
    PERFORM dblink_disconnect( 'copier' );

    UPDATE public.overlap SET
          copied_before_sorted = __copied_before_sorted
        , later_sorted_before_copy = __later_sorted_before_copy
        , copied = __copied
        , state_after_copy = hive.account_operations_copyback_state()
        , not_frozen_pages = ( SELECT count(*) FROM pg_visibility_map( 'hafd.account_operations' ) WHERE NOT all_frozen )
        , not_frozen_rows = ( SELECT count(*) FROM pg_check_frozen( 'hafd.account_operations' ) );
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
    __overlap RECORD;
BEGIN
    SELECT * INTO __overlap FROM public.overlap;
    ASSERT __overlap.state_after_stage = 'sorting', 'hive.proc_restore_indexes did not leave the sort and the copy-back to its caller';
    ASSERT __overlap.refused_before_stage = 'ERROR', 'The copy-back started before the table was staged';
    ASSERT __overlap.state_after_restage = 'sorting', 'The staged table does not await its sort and copy-back';
    ASSERT __overlap.sorted_tables > 2, 'The table was not staged in several ranges';
    ASSERT __overlap.unsorted_at_copyback_start = __overlap.sorted_tables, 'A range was sorted before the copy-back started';
    ASSERT __overlap.copied_before_sorted = 0, 'A range was sorted before the copy-back reached it';
    ASSERT __overlap.later_sorted_before_copy = 0, 'The ranges were not sorted one after another beside the copy-back';
    ASSERT __overlap.copied = 30000, 'The copy-back copied a wrong number of rows';
    ASSERT __overlap.state_after_copy = 'copied', 'The copy-back was not recorded';
    ASSERT __overlap.not_frozen_pages = 0, 'COPY FREEZE left pages of hafd.account_operations not all-frozen in the visibility map';
    ASSERT __overlap.not_frozen_rows = 0, 'COPY FREEZE left rows of hafd.account_operations not frozen';

    ASSERT NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints WHERE table_name = 'hafd.account_operations' AND is_foreign_key = FALSE AND status != 'created' ),
        'Not every index of hafd.account_operations was restored';
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
