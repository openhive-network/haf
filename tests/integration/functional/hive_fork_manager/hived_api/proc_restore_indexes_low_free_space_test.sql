CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible();

    INSERT INTO hafd.account_operations( account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id )
    SELECT ( i * 7919 ) % 97, ( i * 7919 ) % 97, i, i, i % 50 FROM generate_series( 1, 5000 ) i;
    COMMIT;
    INSERT INTO hafd.account_operations( account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id )
    SELECT ( i * 7919 ) % 97, ( i * 7919 ) % 97, i, i, i % 50 FROM generate_series( 5001, 10000 ) i;
    COMMIT;

    -- hive.proc_reorder_account_operations drops it first thing
    CREATE UNLOGGED TABLE hafd.account_operations_reorder_sorted_7 ( LIKE hafd.account_operations );
    ALTER TABLE hafd.account_operations_reorder_sorted_7 OWNER TO hived_group;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- twice the heap, without the default margin of a tenth of it
    PERFORM set_config( 'hive.account_operations_reorder_free_space', ( 2 * pg_relation_size( 'hafd.account_operations' ) )::TEXT, FALSE );
    CALL hive.proc_restore_indexes( 'hafd.account_operations' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_error()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM set_config( 'hive.account_operations_reorder_free_space', 'plenty', FALSE );
    PERFORM hive.account_operations_reorder_space_suffices();
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

    ASSERT to_regclass( 'hafd.account_operations_reorder_sorted_7' ) IS NOT NULL,
        'hive.proc_reorder_account_operations ran although the free space was too little';

    ASSERT ( SELECT indisclustered FROM pg_index WHERE indexrelid = 'hafd.hive_account_operations_uq1'::regclass ),
        'hafd.account_operations is not clustered on hive_account_operations_uq1';

    ASSERT NOT EXISTS(
        SELECT 1 FROM (
            SELECT account_id, account_op_seq_no
                 , lag( account_id ) OVER w AS prev_account_id, lag( account_op_seq_no ) OVER w AS prev_account_op_seq_no
            FROM hafd.account_operations WINDOW w AS ( ORDER BY ctid )
        ) r
        WHERE ( prev_account_id, prev_account_op_seq_no ) > ( account_id, account_op_seq_no )
    ), 'hafd.account_operations is not physically ordered by (account_id, account_op_seq_no)';

    -- CLUSTER keeps the rows' xmin, the rewrite inserts them anew in one transaction
    ASSERT ( SELECT count( DISTINCT xmin::text ) FROM hafd.account_operations ) = 2,
        'hafd.account_operations was not reordered by CLUSTER';
END;
$BODY$
;
