
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block hafd.blocks%ROWTYPE;
    __transaction1 hafd.transactions%ROWTYPE;
    __operation1 hafd.operations%ROWTYPE;
    __signatures1 hafd.transactions_multisig%ROWTYPE;
    __account1 hafd.accounts%ROWTYPE;
    __account_operation1 hafd.account_operations%ROWTYPE;
    __applied_hardforks1 hafd.applied_hardforks%ROWTYPE;
BEGIN
    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
    ;

    PERFORM hive.connect( 'test', 0, 0, 0, TRUE, TRUE );

    __block = ( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
    __transaction1 = ( 101, 0::SMALLINT, '\xDEED', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' );
    __operation1 = ( hafd.operation_id(101, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation, NULL );
    __signatures1 = ( '\xDEED', '\xFEED' );
    __account1 = ( 1, 'alice', 101 );
    __account_operation1 = ( 1, 1, 1, hafd.operation_id(101, 0), 1 );
    __applied_hardforks1 = (1, 101, hafd.operation_id(101, 0));
    PERFORM hive.push_block(
          __block
        , ARRAY[ __transaction1 ]
        , ARRAY[ __signatures1 ]
        , ARRAY[ __operation1 ]
        , ARRAY[ __account1 ]
        , ARRAY[ __account_operation1 ]
        , ARRAY[ __applied_hardforks1 ]
    );
    PERFORM hive.end_massive_sync( 101 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Global views should work in lite schema (recreated by recreate_head_block_views_lite)
    ASSERT ( SELECT COUNT(*) FROM hive.blocks_view WHERE num = 101 ) = 1, 'blocks_view does not work';
    ASSERT ( SELECT COUNT(*) FROM hive.transactions_view WHERE block_num = 101 ) = 1, 'transactions_view does not work';
    ASSERT ( SELECT COUNT(*) FROM hive.operations_view WHERE hafd.operation_id_to_block_num(id) = 101 ) = 1, 'operations_view does not work';
    ASSERT ( SELECT COUNT(*) FROM hive.accounts_view WHERE name = 'alice' ) = 1, 'accounts_view does not work';
    ASSERT ( SELECT COUNT(*) FROM hive.account_operations_view WHERE account_id = 1 ) = 1, 'account_operations_view does not work';
END;
$BODY$
;
