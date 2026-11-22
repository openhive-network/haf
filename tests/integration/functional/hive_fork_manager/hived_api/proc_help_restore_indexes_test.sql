-- A helper (hive.proc_help_restore_indexes) that no hive.proc_restore_indexes waits for does every step
-- of a prepared reorder of hafd.account_operations, builds none of that table's indexes before
-- hive_account_operations_uq1, builds every index of another table and returns.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
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
    CREATE TABLE public.after_help( steps BIGINT, steps_left BIGINT, staged BIGINT, partitions_left BIGINT, sorted_tables BIGINT );
    GRANT ALL ON public.after_help TO PUBLIC;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __pages BIGINT;
BEGIN
    __pages := hive.prepare_account_operations_reorder( 4 );
    COMMIT;
    CALL hive.proc_help_restore_indexes( 'hafd.account_operations' );

    INSERT INTO public.after_help
    SELECT count(*), count(*) FILTER ( WHERE NOT done ), sum( rows ) FILTER ( WHERE kind = 'stage' )
         , ( SELECT count(*) FROM pg_class WHERE relnamespace = 'hafd'::regnamespace AND relname LIKE 'account\_operations\_reorder\_part\_%' )
         , ( SELECT count(*) FROM pg_class WHERE relnamespace = 'hafd'::regnamespace AND relname LIKE 'account\_operations\_reorder\_sorted\_%' )
    FROM hafd.account_operations_reorder_steps;
    COMMIT;

    PERFORM hive.finish_account_operations_reorder( __pages );
    COMMIT;

    CALL hive.proc_help_restore_indexes( 'hafd.blocks' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_error()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    CALL hive.proc_help_restore_indexes( 'hafd.blocks' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_error()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM set_config( 'hive.index_restore_helpers', 'many', FALSE );
    PERFORM hive.index_restore_helpers( 'hafd.blocks', 32 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __after RECORD;
BEGIN
    SELECT * INTO __after FROM public.after_help;
    ASSERT __after.steps > 2, 'The reorder was not split into several steps';
    ASSERT __after.steps_left = 0, 'The helper left steps of the reorder undone';
    ASSERT __after.staged = 30000, 'The helper staged a wrong number of rows';
    ASSERT __after.partitions_left = 0, 'The helper left staging partitions unsorted';
    ASSERT __after.sorted_tables > 1, 'The helper did not sort the account ranges';

    ASSERT NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints WHERE table_name = 'hafd.account_operations' AND is_foreign_key = FALSE AND status != 'missing' ),
        'The helper built an index of hafd.account_operations before hive_account_operations_uq1';
    ASSERT EXISTS( SELECT 1 FROM hafd.indexes_constraints WHERE table_name = 'hafd.blocks' AND is_foreign_key = FALSE ),
        'hafd.blocks has no index to restore';
    ASSERT NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints WHERE table_name = 'hafd.blocks' AND is_foreign_key = FALSE AND status != 'created' ),
        'The helper did not build every index of hafd.blocks';

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

    ASSERT hive.index_restore_helpers( 'hafd.account_operations', 32 ) = 3, 'Wrong helper count for 32 threads';
    ASSERT hive.index_restore_helpers( 'hafd.account_operations', 16 ) = 1, 'Wrong helper count for 16 threads';
    ASSERT hive.index_restore_helpers( 'hafd.account_operations', 8 ) = 0, 'Wrong helper count for 8 threads';
    ASSERT hive.index_restore_helpers( 'hafd.account_operations', 128 ) = 3, 'Wrong helper count for 128 threads';
    ASSERT hive.index_restore_helpers( 'hafd.operations', 32 ) = 0, 'hafd.operations has helpers by default';
    PERFORM set_config( 'hive.index_restore_helpers', '2', TRUE );
    ASSERT hive.index_restore_helpers( 'hafd.operations', 8 ) = 2, 'hive.index_restore_helpers is not obeyed';
END;
$BODY$
;
