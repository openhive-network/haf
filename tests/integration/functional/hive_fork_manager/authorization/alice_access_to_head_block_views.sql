-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE test_hived_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    -- Create blocks 1-5
    PERFORM test.create_blocks(1, 5);

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
    ;

    INSERT INTO hafd.blocks
    VALUES
    ( hafd.make_block_id(4, 1), '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(5, 1), '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(6, 1), '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(7, 1), '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 ) -- must be overriden by fork 2
         , ( hafd.make_block_id(8, 1), '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 ) -- must be overriden by fork 2
         , ( hafd.make_block_id(9, 1), '\xBADD9001', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 ) -- must be overriden by fork 2
         , ( hafd.make_block_id(7, 2), '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(8, 2), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(9, 2), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(8, 3), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(9, 3), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(10, 3), '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.transactions
    VALUES
    ( hafd.make_block_id(1, 0), 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(2, 0), 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(3, 0), 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(4, 0), 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(5, 0), 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.transactions_multisig(trx_hash, signature, block_id)
    VALUES
      ( '\xDEED10', '\xBAAD10', hafd.make_block_id(1, 0) )
    , ( '\xDEED20', '\xBAAD20', hafd.make_block_id(2, 0) )
    , ( '\xDEED30', '\xBAAD30', hafd.make_block_id(3, 0) )
    , ( '\xDEED40', '\xBAAD40', hafd.make_block_id(4, 0) )
    , ( '\xDEED50', '\xBAAD50', hafd.make_block_id(5, 0) )
    ;

    -- Irreversible operations (fork_id=0)
    INSERT INTO hafd.operations(block_id, seq_in_block, op_type_id, trx_in_block, op_pos, body_binary, id)
    VALUES
           ( hafd.make_block_id(1, 0), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(1, 0, 1) )
         , ( hafd.make_block_id(2, 0), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(2, 0, 1) )
         , ( hafd.make_block_id(3, 0), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(3, 0, 1) )
         , ( hafd.make_block_id(4, 0), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(4, 0, 1) )
         , ( hafd.make_block_id(5, 0), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(5, 0, 1) )
    ;

    -- Reversible operations with different fork_ids encoded in block_id
    INSERT INTO hafd.operations(block_id, seq_in_block, op_type_id, trx_in_block, op_pos, body_binary, id)
    VALUES
           ( hafd.make_block_id(4, 1), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(4, 0, 1) )
         , ( hafd.make_block_id(5, 1), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVEFIVE OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(5, 0, 1) )
         , ( hafd.make_block_id(6, 1), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(6, 0, 1) )
         , ( hafd.make_block_id(7, 1), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN0 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(7, 0, 1) ) -- must be abandon because of fork2
         , ( hafd.make_block_id(7, 1), 1, 1, 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN01 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(7, 1, 1) ) -- must be abandon because of fork2
         , ( hafd.make_block_id(7, 1), 2, 1, 0, 2, '{"type":"system_warning_operation","value":{"message":"SEVEN02 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(7, 2, 1) ) -- must be abandon because of fork2
         , ( hafd.make_block_id(7, 2), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(7, 0, 1) )
         , ( hafd.make_block_id(7, 2), 1, 1, 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(7, 1, 1) )
         , ( hafd.make_block_id(8, 2), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"EAIGHT2 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(8, 0, 1) )
         , ( hafd.make_block_id(9, 2), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(9, 0, 1) )
         , ( hafd.make_block_id(8, 3), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(8, 0, 1) )
         , ( hafd.make_block_id(9, 3), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(9, 0, 1) )
         , ( hafd.make_block_id(10, 3), 0, 1, 0, 0, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(10, 0, 1) )
    ;

    INSERT INTO hafd.accounts
    VALUES
    ( 1, 'alice1', hafd.make_block_id(1, 0) )
         , ( 2, 'alice2', hafd.make_block_id(2, 0) )
         , ( 3, 'alice3', hafd.make_block_id(3, 0) )
         , ( 4, 'alice4', hafd.make_block_id(4, 0) )
    ;

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES
           ( 4, 'alice41', hafd.make_block_id(4, 1) )
         , ( 5, 'alice51', hafd.make_block_id(5, 1) )
         , ( 6, 'alice61', hafd.make_block_id(6, 1) )
         , ( 7, 'alice71', hafd.make_block_id(7, 1) ) -- must be overriden by fork 2
         , ( 8, 'bob71', hafd.make_block_id(7, 1) )   -- must be overriden by fork 2
         , ( 9, 'alice81', hafd.make_block_id(8, 1) ) -- must be overriden by fork 2
         , ( 9, 'alice91', hafd.make_block_id(9, 2) ) -- must be overriden by fork 2
         , ( 7, 'alice72', hafd.make_block_id(7, 2) )
         , ( 8, 'bob72', hafd.make_block_id(7, 2) )
         , ( 10, 'alice92', hafd.make_block_id(9, 2) )
         , ( 9, 'alice83', hafd.make_block_id(8, 3) )
         , ( 10, 'alice93', hafd.make_block_id(9, 3) )
         , ( 11, 'alice103', hafd.make_block_id(10, 3) )
    ;

    -- Irreversible account_operations (references operations by block_id, seq_in_block)
    INSERT INTO hafd.account_operations(block_id, seq_in_block, account_id, transacting_account_id, account_op_seq_no)
    VALUES
           ( hafd.make_block_id(1, 0), 0, 1, 1, 1 )
         , ( hafd.make_block_id(2, 0), 0, 1, 1, 2 )
         , ( hafd.make_block_id(2, 0), 0, 2, 2, 1 )
         , ( hafd.make_block_id(3, 0), 0, 3, 3, 1 )
         , ( hafd.make_block_id(4, 0), 0, 4, 4, 1 )
    ;

    -- Reversible account_operations
    INSERT INTO hafd.account_operations(block_id, seq_in_block, account_id, transacting_account_id, account_op_seq_no)
    VALUES
           ( hafd.make_block_id(4, 1), 0, 4, 4, 1 )
         , ( hafd.make_block_id(5, 1), 0, 5, 5, 1 )
         , ( hafd.make_block_id(6, 1), 0, 6, 6, 1 )
         , ( hafd.make_block_id(7, 1), 0, 7, 7, 1 ) -- must be overriden by fork 2
         , ( hafd.make_block_id(7, 1), 1, 8, 8, 1 ) -- must be overriden by fork 2
         , ( hafd.make_block_id(7, 1), 2, 9, 9, 1 ) -- must be overriden by fork 2
         , ( hafd.make_block_id(7, 2), 0, 7, 7, 2 )
         , ( hafd.make_block_id(7, 2), 1, 8, 8, 2 ) -- will be abandoned since fork 3 doesn not have this account operation
         , ( hafd.make_block_id(8, 2), 0, 9, 9, 2 )
         , ( hafd.make_block_id(7, 2), 0, 9, 9, 3 )
         , ( hafd.make_block_id(9, 2), 0, 10, 10, 2 )
         , ( hafd.make_block_id(8, 3), 0, 9, 9, 3 )
         , ( hafd.make_block_id(9, 3), 0, 10, 10, 3 )
         , ( hafd.make_block_id(10, 3), 0, 11, 11, 3 )
    ;

    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(4, 0);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT (SELECT COUNT(*) FROM hive.blocks_view) > 0, 'Alice has no access to hive.blocks_view';
    ASSERT (SELECT COUNT(*) FROM hive.transactions_view) > 0, 'Alice has no access to hive.transactions_view';
    ASSERT (SELECT COUNT(*) FROM hive.transactions_multisig_view) > 0, 'Alice has no access to hive.transactions_multisig_view';
    ASSERT (SELECT COUNT(*) FROM hafd.operations) > 0, 'Alice has no access to hafd.operations';
    ASSERT (SELECT COUNT(*) FROM hafd.accounts) > 0, 'Alice has no access to hafd.accounts';
    ASSERT (SELECT COUNT(*) FROM hafd.account_operations) > 0, 'Alice has no access to hafd.account_operations';
END;
$BODY$
;
