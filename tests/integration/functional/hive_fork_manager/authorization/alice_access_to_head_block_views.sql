CREATE OR REPLACE PROCEDURE test_hived_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive_data.operation_types
    VALUES ( 0, 'OP 0', FALSE )
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
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive_data.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    INSERT INTO hive_data.blocks_reversible
    VALUES
    ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 ) -- must be overriden by fork 2
         , ( 8, '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 ) -- must be overriden by fork 2
         , ( 9, '\xBADD9001', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 ) -- must be overriden by fork 2
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
    ;

    INSERT INTO hive_data.transactions
    VALUES
    ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( 3, 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
         , ( 5, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hive_data.transactions_multisig
    VALUES
    ( '\xDEED10', '\xBAAD10' )
         , ( '\xDEED20', '\xBAAD20' )
         , ( '\xDEED30', '\xBAAD30' )
         , ( '\xDEED40', '\xBAAD40' )
         , ( '\xDEED50', '\xBAAD50' )
    ;

    INSERT INTO hive_data.operations
    VALUES
           ( hive.operation_id(1, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hive_data.operation )
         , ( hive.operation_id(2, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hive_data.operation )
         , ( hive.operation_id(3, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb :: hive_data.operation )
         , ( hive.operation_id(4, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hive_data.operation )
         , ( hive.operation_id(5, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hive_data.operation )
    ;

    INSERT INTO hive_data.operations_reversible(id, trx_in_block, op_pos, body_binary, fork_id)
    VALUES
           ( hive.operation_id(4,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hive_data.operation, 1 )
         , ( hive.operation_id(5,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVEFIVE OPERATION"}}' :: jsonb :: hive_data.operation, 1 )
         , ( hive.operation_id(6,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb :: hive_data.operation, 1 )
         , ( hive.operation_id(7,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN0 OPERATION"}}' :: jsonb :: hive_data.operation, 1 ) -- must be abandon because of fork2
         , ( hive.operation_id(7,1,1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN01 OPERATION"}}' :: jsonb :: hive_data.operation, 1 ) -- must be abandon because of fork2
         , ( hive.operation_id(7,1,2), 0, 2, '{"type":"system_warning_operation","value":{"message":"SEVEN02 OPERATION"}}' :: jsonb :: hive_data.operation, 1 ) -- must be abandon because of fork2
         , ( hive.operation_id(7,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hive_data.operation, 2 )
         , ( hive.operation_id(7,1,1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hive_data.operation, 2 )
         , ( hive.operation_id(8,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EAIGHT2 OPERATION"}}' :: jsonb :: hive_data.operation, 2 )
         , ( hive.operation_id(9,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hive_data.operation, 2 )
         , ( hive.operation_id(8,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hive_data.operation, 3 )
         , ( hive.operation_id(9,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hive_data.operation, 3 )
         , ( hive.operation_id(10,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hive_data.operation, 3 )
    ;

    INSERT INTO hive_data.accounts
    VALUES
    ( 1, 'alice1', 1 )
         , ( 2, 'alice2', 2 )
         , ( 3, 'alice3', 3 )
         , ( 4, 'alice4', 4 )
    ;

    INSERT INTO hive_data.accounts_reversible
    VALUES
           ( 4, 'alice41', 4, 1 )
         , ( 5, 'alice51', 5, 1 )
         , ( 6, 'alice61', 6, 1 )
         , ( 7, 'alice71', 7, 1 ) -- must be overriden by fork 2
         , ( 8, 'bob71', 7, 1 )   -- must be overriden by fork 2
         , ( 9, 'alice81', 8, 1 ) -- must be overriden by fork 2
         , ( 9, 'alice91', 9, 2 ) -- must be overriden by fork 2
         , ( 7, 'alice72', 7, 2 )
         , ( 8, 'bob72', 7, 2 )
         , ( 10, 'alice92', 9, 2 )
         , ( 9, 'alice83', 8, 3 )
         , ( 10, 'alice93', 9, 3 )
         , ( 11, 'alice103', 10, 3 )
    ;

    INSERT INTO hive_data.account_operations(account_id, account_op_seq_no, operation_id)
    VALUES
           ( 1, 1, hive.operation_id(1, 1, 0) )
         , ( 1, 2, hive.operation_id(2, 1, 0) )
         , ( 2, 1, hive.operation_id(2, 1, 0) )
         , ( 3, 1, hive.operation_id(3, 1, 0) )
         , ( 4, 1, hive.operation_id(4, 1, 0) )
    ;

    INSERT INTO hive_data.account_operations_reversible
    VALUES
           ( 4, 1, hive.operation_id(4,1,0), 1 )
         , ( 5, 1, hive.operation_id(5,1,0), 1 )
         , ( 6, 1, hive.operation_id(6,1,0), 1 )
         , ( 7, 1, hive.operation_id(7,1,0), 1 ) -- must be overriden by fork 2
         , ( 8, 1, hive.operation_id(7,1,1), 1 ) -- must be overriden by fork 2
         , ( 9, 1, hive.operation_id(7,1,2), 1 ) -- must be overriden by fork 2
         , ( 7, 2, hive.operation_id(7,1,0), 2 )
         , ( 8, 2, hive.operation_id(7,1,1), 2 ) -- will be abandoned since fork 3 doesn not have this account operation
         , ( 9, 2, hive.operation_id(8,1,0), 2 )
         , ( 9, 3, hive.operation_id(7,1,0), 2 )
         , ( 10, 2, hive.operation_id(9,1,0), 2 )
         , ( 9, 3, hive.operation_id(8,1,0), 3 )
         , ( 10, 3, hive.operation_id(9,1,0), 3 )
         , ( 11, 3, hive.operation_id(10,1,0), 3 )
    ;

    UPDATE hive_data.irreversible_data SET consistent_block = 4;
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
    ASSERT (SELECT COUNT(*) FROM hive_data.operations) > 0, 'Alice has no access to hive_data.operations';
    ASSERT (SELECT COUNT(*) FROM hive_data.accounts) > 0, 'Alice has no access to hive_data.accounts';
    ASSERT (SELECT COUNT(*) FROM hive_data.account_operations) > 0, 'Alice has no access to hive_data.account_operations';
END;
$BODY$
;
