CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible();

    -- inserted in operation order, two transactions, as a replay leaves the table
    INSERT INTO hafd.account_operations( account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id )
    SELECT ( i * 7919 ) % 97, ( i * 7919 ) % 97, i, i, i % 50 FROM generate_series( 1, 15000 ) i;
    COMMIT;
    INSERT INTO hafd.account_operations( account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id )
    SELECT ( i * 7919 ) % 97, ( i * 7919 ) % 97, i, i, i % 50 FROM generate_series( 15001, 30000 ) i;
    COMMIT;

    CREATE TABLE public.account_operations_before AS SELECT * FROM hafd.account_operations;
    CREATE TABLE public.relation_before AS
    SELECT oid, reltype, relacl::text, reloptions::text FROM pg_class WHERE oid = 'hafd.account_operations'::regclass;

    -- left behind by an interrupted reorder
    CREATE UNLOGGED TABLE hafd.account_operations_reorder_sorted_7 ( LIKE hafd.account_operations );
    INSERT INTO hafd.account_operations_reorder_sorted_7 SELECT * FROM hafd.account_operations LIMIT 10;
    ALTER TABLE hafd.account_operations_reorder_sorted_7 OWNER TO hived_group;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- a few pages per step, so the table is staged, sorted and copied back in many ranges
    CALL hive.proc_reorder_account_operations( 4 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_error()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    CALL hive.proc_reorder_account_operations( 4 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_error()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    CALL hive.proc_reorder_account_operations( 0 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT count(*) FROM hafd.account_operations ) = 30000, 'Rows were lost or duplicated';
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

    ASSERT ( SELECT count( DISTINCT xmin::text ) FROM hafd.account_operations ) = 1,
        'The sorted rows were not copied back in one transaction';

    ASSERT NOT EXISTS(
        SELECT oid, reltype, relacl::text, reloptions::text FROM pg_class WHERE oid = 'hafd.account_operations'::regclass
        EXCEPT
        SELECT * FROM public.relation_before
    ), 'hafd.account_operations was replaced or lost its grants or options';

    ASSERT NOT EXISTS( SELECT 1 FROM pg_class WHERE relnamespace = 'hafd'::regnamespace AND relname LIKE 'account\_operations\_reorder\_%' ),
        'The reorder left its staging tables behind';

    ASSERT ( SELECT count(*) FROM hive.irreversible_account_operations_view ) = 30000,
        'hive.irreversible_account_operations_view does not read the reordered table';
END;
$BODY$
;
