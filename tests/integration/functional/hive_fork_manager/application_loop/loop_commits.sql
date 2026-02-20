\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE test_hived_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM test.create_blocks(1, 8);

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
    ;

    -- Set block 8 as irreversible (test needs to attach at block 7)
    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(8, 0);
END;
$BODY$;


CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __context_stages hafd.application_stages :=
        ARRAY[
            hive.stage('massive',2 ,100 )
            , hafd.live_stage()
            ];
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( 'alice', 'alice', _stages => __context_stages );

    CREATE TABLE alice_table( value INTEGER );
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
    UPDATE hafd.contexts SET current_block_num = 7; -- to open any transaction
    ASSERT pg_current_xact_id_if_assigned() IS NOT NULL, 'no tx at start';

    __tx_id_before_next_id :=  txid_current();
    CALL hive.app_next_iteration( 'alice', __range_placeholder );
    ASSERT txid_current() != __tx_id_before_next_id, 'previous tx not closed';

    __tx_id_before_next_id :=  txid_current();
    PERFORM * FROM hafd.blocks;
    INSERT INTO alice_table VALUES (10),(11),(12);
    CALL hive.app_next_iteration( 'alice', __range_placeholder );
    ASSERT txid_current() != __tx_id_before_next_id, 'previous tx not closed(2)';
END;
$BODY$;
