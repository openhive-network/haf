CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( 'alice', 'alice' );
END;
$BODY$;



CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __tx_id_before_next_id BIGINT;
    __range_placeholder hive.blocks_range;
BEGIN
    UPDATE hive.contexts SET current_block_num = 7; -- to open any transaction
    ASSERT pg_current_xact_id_if_assigned() IS NOT NULL, 'no tx at start';

    __tx_id_before_next_id :=  txid_current();
    CALL hive.app_next_iteration( ARRAY[ 'alice' ], __range_placeholder );
    ASSERT txid_current() != __tx_id_before_next_id, 'previous tx not closed';
END;
$BODY$;