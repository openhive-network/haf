DROP FUNCTION IF EXISTS assert_uq1_definition;
CREATE FUNCTION assert_uq1_definition( _when TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT pg_get_constraintdef( c.oid ) FROM pg_constraint c
             WHERE c.conrelid = 'hafd.account_operations'::regclass AND c.conname = 'hive_account_operations_uq1' )
           = 'UNIQUE (account_id, account_op_seq_no) INCLUDE (op_type_id)'
         , format( 'hive_account_operations_uq1 is not UNIQUE (account_id, account_op_seq_no) INCLUDE (op_type_id) %s', _when );

    ASSERT ( SELECT ix.indisunique AND ix.indnkeyatts = 2 AND ix.indnatts = 3
             FROM pg_index ix WHERE ix.indexrelid = 'hafd.hive_account_operations_uq1'::regclass )
         , format( 'hive_account_operations_uq1 index is not unique on two key columns plus one included column %s', _when );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM assert_uq1_definition( 'after install' );

    PERFORM hive.disable_fk_of_irreversible();
    INSERT INTO hafd.account_operations( account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id )
    SELECT s % 10, s % 10, s / 10, s, ( s % 7 )::SMALLINT
    FROM generate_series( 1, 1000 ) s;

    PERFORM hive.disable_indexes_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.enable_indexes_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM assert_uq1_definition( 'after restore' );

    ASSERT ( SELECT indisclustered FROM pg_index WHERE indexrelid = 'hafd.hive_account_operations_uq1'::regclass )
         , 'hafd.account_operations is not clustered on hive_account_operations_uq1 after restore';

    BEGIN
        INSERT INTO hafd.account_operations( account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id )
        VALUES ( 3, 3, 50, 100000, 1 );
        ASSERT FALSE, 'duplicate (account_id, account_op_seq_no) was accepted';
    EXCEPTION WHEN unique_violation THEN
    END;
END;
$BODY$
;
