-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE table1( id INT ) INHERITS( a.context );

    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE )
        , ( 1, 'OP 1', FALSE )
        , ( 2, 'OP 2', FALSE )
        , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    -- Irreversible blocks (fork_id=0)
    INSERT INTO hafd.blocks
    VALUES
          ( hafd.make_block_id(1, 0), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(2, 0), '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(3, 0), '\xBADD30', '\xCAFE301234', '2016-06-22 19:10:23-07'::timestamp, 5, '\x40071234', E'[{"version":"1.26"}]', '\x21571234', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(4, 0), '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(5, 0), '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
    ;

    -- Transactions use new schema: (block_id, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature)
    INSERT INTO hafd.transactions
    VALUES
          ( hafd.make_block_id(1, 0), 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(2, 0), 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(3, 0), 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(3, 0), 1::SMALLINT, '\xDEED31', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF0003' )
        , ( hafd.make_block_id(4, 0), 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(5, 0), 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    -- transactions_multisig: (block_id, trx_in_block, signature)
    INSERT INTO hafd.transactions_multisig
    VALUES
          ( hafd.make_block_id(1, 0), 0::SMALLINT, '\xBEEF01' )
        , ( hafd.make_block_id(2, 0), 0::SMALLINT, '\xBEEF01' )
        , ( hafd.make_block_id(3, 0), 0::SMALLINT, '\xBEEF01' )
        , ( hafd.make_block_id(3, 0), 1::SMALLINT, '\xBEEF000302' )
        , ( hafd.make_block_id(3, 0), 1::SMALLINT, '\xBEEF000303' )
    ;

    -- Operations: (block_id, seq_in_block, op_type_id, trx_in_block, op_pos, body_binary)
    -- Note: op_type_id 3 is a virtual op (is_virtual=TRUE), so use non-virtual types (0,1,2) for regular operations
    INSERT INTO hafd.operations(block_id, seq_in_block, op_type_id, trx_in_block, op_pos, body_binary)
    VALUES
          ( hafd.make_block_id(1, 0), 1, 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation )
        , ( hafd.make_block_id(2, 0), 1, 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation )
        , ( hafd.make_block_id(3, 0), 1, 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 00"}}' :: jsonb :: hafd.operation )
        , ( hafd.make_block_id(3, 0), 2, 1, 0, 1, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 01"}}' :: jsonb :: hafd.operation )
        , ( hafd.make_block_id(3, 0), 3, 2, 1, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 10"}}' :: jsonb :: hafd.operation )
        , ( hafd.make_block_id(3, 0), 4, 2, 1, 1, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 11"}}' :: jsonb :: hafd.operation )
        , ( hafd.make_block_id(4, 0), 1, 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation )
        , ( hafd.make_block_id(5, 0), 1, 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hafd.operation )
    ;

    -- Reversible blocks with fork_id > 0 (unified table)
    INSERT INTO hafd.blocks
    VALUES
          ( hafd.make_block_id(4, 1), '\xBADD40', '\xCAFE42', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(5, 1), '\xBADD50', '\xCAFE52', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(6, 1), '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(7, 1), '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(8, 1), '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(9, 1), '\xBADD9001', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(7, 2), '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(8, 2), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(9, 2), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(8, 3), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(9, 3), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(10, 3), '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    UPDATE hafd.hive_state SET consistent_block = 5;
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

    __transaction1 = (101, 100, '2016-06-22 19:10:23-07'::timestamp, ARRAY[ '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 00"}}' :: jsonb :: hafd.operation, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 01"}}' :: jsonb :: hafd.operation ], array_to_json(ARRAY[]::INT[]), ARRAY[ '\xBEEF'::bytea, '\xBEEF01'::bytea ]);
    __transaction2 = (101, 100, '2016-06-22 19:10:23-07'::timestamp, ARRAY[ '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 10"}}' :: jsonb :: hafd.operation, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION 11"}}' :: jsonb :: hafd.operation ], array_to_json(ARRAY[]::INT[]), ARRAY[ '\xBEEF0003'::bytea, '\xBEEF000302'::bytea, '\xBEEF000303'::bytea ]);

    ASSERT __block.transactions = Array[ __transaction1, __transaction2 ], 'Incorrect transactions array';
    ASSERT __block.block_id = '\xBADD30'::bytea, 'Incorrect block_id';
    ASSERT __block.signing_key = 'STM65w', 'Incorrect signing_key';
    ASSERT __block.transaction_ids = ARRAY[ '\xDEED30'::bytea, '\xDEED31'::bytea ], 'Incorrect transaction_ids array';
END
$BODY$
;
