
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE table1( id INT ) INHERITS( a.context );

    INSERT INTO hive_data.operation_types
    VALUES (0, 'OP 0', FALSE )
        , ( 1, 'OP 1', FALSE )
        , ( 2, 'OP 2', FALSE )
        , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive_data.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hive_data.blocks
    VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 3, '\xBADD30', '\xCAFE301234', '2016-06-22 19:10:23-07'::timestamp, 5, '\x40071234', E'[{"version":"1.26"}]', '\x21571234', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive_data.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    INSERT INTO hive_data.transactions
    VALUES
          ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
        , ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
        , ( 3, 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
        , ( 3, 1::SMALLINT, '\xDEED31', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF0003' )
        , ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
        , ( 5, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hive_data.transactions_multisig
    VALUES
          ( '\xDEED10', '\xBEEF01' )
        , ( '\xDEED20', '\xBEEF01' )
        , ( '\xDEED30', '\xBEEF01' )
        , ( '\xDEED31', '\xBEEF000302' )
        , ( '\xDEED31', '\xBEEF000303' )
    ;

    INSERT INTO hive_data.operations
    VALUES
          ( hive.operation_id(1, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hive_data.operation )
        , ( hive.operation_id(2, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hive_data.operation )
        , ( hive.operation_id(3, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 00"}}' :: jsonb :: hive_data.operation )
        , ( hive.operation_id(3, 1, 1), 0, 1, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 01"}}' :: jsonb :: hive_data.operation )
        , ( hive.operation_id(3, 1, 2), 1, 2, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 10"}}' :: jsonb :: hive_data.operation )
        , ( hive.operation_id(3, 1, 3), 1, 3, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 11"}}' :: jsonb :: hive_data.operation )
        , ( hive.operation_id(4, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hive_data.operation )
        , ( hive.operation_id(5, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hive_data.operation )
    ;

    INSERT INTO hive_data.blocks_reversible
    VALUES
          ( 4, '\xBADD40', '\xCAFE42', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
        , ( 5, '\xBADD50', '\xCAFE52', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
        , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
        , ( 7, '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
        , ( 8, '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
        , ( 9, '\xBADD9001', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
        , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
        , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
        , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
        , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
        , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
        , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
    ;

    UPDATE hive_data.irreversible_data SET consistent_block = 5;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block hive.block_type;
    __transaction1 hive.transaction_type;
    __transaction2 hive.transaction_type;
BEGIN
    SELECT * FROM hive.get_block( 3 ) INTO __block;
    RAISE NOTICE 'Block = %', __block;
    RAISE NOTICE 'Transactions array = %', __block.transactions;
    RAISE NOTICE 'Transactions first element = %', __block.transactions[1];
    RAISE NOTICE 'Transactions second element = %', __block.transactions[2];

    ASSERT __block.previous = '\xCAFE301234'::bytea, 'Incorrect previous block hash';
    ASSERT __block.timestamp = '2016-06-22 19:10:23-07'::timestamp, 'Incorrect timestamp';
    ASSERT __block.witness = 'initminer', 'Incorrect witness name';
    ASSERT __block.transaction_merkle_root = '\x40071234'::bytea, 'Incorrect transaction merkle root';
    ASSERT __block.extensions = E'[{"version":"1.26"}]'::jsonb, 'Incorrect extensions';
    ASSERT __block.witness_signature = '\x21571234'::bytea, 'Incorrect witness signature';

    __transaction1 = (101, 100, '2016-06-22 19:10:23-07'::timestamp, ARRAY[ '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 00"}}' :: jsonb :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 01"}}' :: jsonb :: hive_data.operation ], array_to_json(ARRAY[]::INT[]), ARRAY[ '\xBEEF'::bytea, '\xBEEF01'::bytea ]);
    __transaction2 = (101, 100, '2016-06-22 19:10:23-07'::timestamp, ARRAY[ '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 10"}}' :: jsonb :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 11"}}' :: jsonb :: hive_data.operation ], array_to_json(ARRAY[]::INT[]), ARRAY[ '\xBEEF0003'::bytea, '\xBEEF000302'::bytea, '\xBEEF000303'::bytea ]);

    ASSERT __block.transactions = Array[ __transaction1, __transaction2 ], 'Incorrect transactions array';
    ASSERT __block.block_id = '\xBADD30'::bytea, 'Incorrect block_id';
    ASSERT __block.signing_key = 'STM65w', 'Incorrect signing_key';
    ASSERT __block.transaction_ids = ARRAY[ '\xDEED30'::bytea, '\xDEED31'::bytea ], 'Incorrect transaction_ids array';
END
$BODY$
;
