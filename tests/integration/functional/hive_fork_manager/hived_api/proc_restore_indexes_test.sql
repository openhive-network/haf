CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE TABLE public.constraints_before AS
    SELECT conrelid::regclass::text AS table_name, conname, contype, pg_get_constraintdef( oid ) AS definition
    FROM pg_constraint
    WHERE connamespace = 'hafd'::regnamespace AND contype IN ( 'p', 'u' );

    CREATE TABLE public.indexes_before AS
    SELECT schemaname, tablename, indexname, indexdef FROM pg_indexes WHERE schemaname = 'hafd';

    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible();

    -- a restore interrupted after it built hive_account_operations_uq1, before the CLUSTER committed
    ASSERT hive.restore_account_operations_cluster_index(), 'hive_account_operations_uq1 was not built';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    CALL hive.proc_restore_indexes( 'hafd.blocks' );
    CALL hive.proc_restore_indexes( 'hafd.hive_state' );
    CALL hive.proc_restore_indexes( 'hafd.transactions' );
    CALL hive.proc_restore_indexes( 'hafd.transactions_multisig' );
    CALL hive.proc_restore_indexes( 'hafd.operations' );
    CALL hive.proc_restore_indexes( 'hafd.accounts' );
    CALL hive.proc_restore_indexes( 'hafd.account_operations' );
    CALL hive.proc_restore_indexes( 'hafd.applied_hardforks' );
    PERFORM hive.enable_fk_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints WHERE status != 'created' ), 'Not every index was restored';

    -- every restored index or constraint got its status in a transaction of its own
    ASSERT ( SELECT count( DISTINCT xmin::text ) = count(*) FROM hafd.indexes_constraints
              WHERE is_foreign_key = FALSE AND table_name IN ( 'hafd.blocks', 'hafd.transactions', 'hafd.transactions_multisig', 'hafd.operations'
                                                             , 'hafd.applied_hardforks', 'hafd.accounts', 'hafd.account_operations' ) ),
        'Two indexes were restored in one transaction';

    ASSERT ( SELECT indisclustered FROM pg_index WHERE indexrelid = 'hafd.hive_account_operations_uq1'::regclass ),
        'hafd.account_operations is not clustered on hive_account_operations_uq1';

    ASSERT NOT EXISTS(
        SELECT table_name, conname, contype, definition FROM public.constraints_before
        EXCEPT
        SELECT conrelid::regclass::text, conname, contype, pg_get_constraintdef( oid )
        FROM pg_constraint WHERE connamespace = 'hafd'::regnamespace AND contype IN ( 'p', 'u' )
    ), 'A PK/UNIQUE constraint was not restored as it was';

    ASSERT NOT EXISTS(
        SELECT * FROM public.indexes_before
        EXCEPT
        SELECT schemaname, tablename, indexname, indexdef FROM pg_indexes WHERE schemaname = 'hafd'
    ), 'An index was not restored as it was';
END;
$BODY$
;
