CREATE OR REPLACE PROCEDURE hived_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;
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