
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hafd.operation_types
    VALUES ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hafd.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 7, '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 8, '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (15, 'initminer', 1)
         , (16, 'alice', 1)
         , (17, 'bob', 1)
    ;

    INSERT INTO hafd.blocks_reversible
    VALUES
           ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 ) -- must be overriden by fork 2
         , ( 8, '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 ) -- must be overriden by fork 2
         , ( 9, '\xBADD9001', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 ) -- must be overriden by fork 2
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
    ;

    INSERT INTO hafd.operations
    VALUES
           ( hafd.operation_id(1, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(2, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(3, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(4, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(5, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(6, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(7, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(7, 1, 1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(8, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EAIGHT2 OPERATION"}}' :: jsonb :: hafd.operation )
    ;

    INSERT INTO hafd.operations_reversible(id, trx_in_block, op_pos, body_binary, fork_id)
    VALUES
           ( hafd.operation_id(4, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(5, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVEFIVE OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(6, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(7, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN0 OPERATION"}}' :: jsonb :: hafd.operation, 1 ) -- must be abandon because of fork2
         , ( hafd.operation_id(7, 1, 1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN01 OPERATION"}}' :: jsonb :: hafd.operation, 1 ) -- must be abandon because of fork2
         , ( hafd.operation_id(7, 1, 2), 0, 2, '{"type":"system_warning_operation","value":{"message":"SEVEN02 OPERATION"}}' :: jsonb :: hafd.operation, 1 ) -- must be abandon because of fork2
         , ( hafd.operation_id(7, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(7, 1, 1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(8, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EAIGHT2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(9, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(8, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hafd.operation, 3 )
         , ( hafd.operation_id(9, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hafd.operation, 3 )
         , ( hafd.operation_id(10, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hafd.operation, 3 )
    ;

    INSERT INTO hafd.accounts
    VALUES
           ( 1, 'alice1', 1 )
         , ( 2, 'alice2', 1 )
         , ( 3, 'alice3', 1 )
         , ( 4, 'alice4', 1 )
         , ( 5, 'alice5', 1 )
         , ( 6, 'alice6', 1 )
         , ( 7, 'alice7', 1 )
         , ( 8, 'alice8', 1 )
         , ( 9, 'alice9', 1 )
    ;

    INSERT INTO hafd.accounts_reversible
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

    INSERT INTO hafd.account_operations(account_id, account_op_seq_no, operation_id)
    VALUES
           ( 1, 1, hafd.operation_id(1, 1, 0) )
         , ( 1, 2, hafd.operation_id(2, 1, 0) )
         , ( 2, 1, hafd.operation_id(2, 1, 0) )
         , ( 3, 1, hafd.operation_id(3, 1, 0) )
         , ( 4, 1, hafd.operation_id(4, 1, 0) )
    ;

    INSERT INTO hafd.account_operations_reversible
    VALUES
           ( 4, 1, hafd.operation_id(4, 1, 0), 1 )
         , ( 5, 1, hafd.operation_id(5, 1, 0), 1 )
         , ( 6, 1, hafd.operation_id(6, 1, 0), 1 )
         , ( 7, 1, hafd.operation_id(7, 1, 0), 1 ) -- must be overriden by fork 2
         , ( 8, 1, hafd.operation_id(7, 1, 0), 1 ) -- must be overriden by fork 2
         , ( 9, 1, hafd.operation_id(7, 1, 2), 1 ) -- must be overriden by fork 2
         , ( 7, 2, hafd.operation_id(7, 1, 0), 2 )
         , ( 8, 2, hafd.operation_id(7, 1, 1), 2 )
         , ( 9, 2, hafd.operation_id(8, 1, 0), 2 )
         , ( 9, 3, hafd.operation_id(7, 1, 0), 2 )
         , ( 10, 2, hafd.operation_id(9, 1, 0), 2 )
         , ( 9, 3, hafd.operation_id(9, 1, 0), 3 )
         , ( 10, 3, hafd.operation_id(10, 1, 0), 3 )
         , ( 11, 3, hafd.operation_id(10, 1, 0), 3 )
    ;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.copy_account_operations_to_irreversible( 4, 8 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS (
        SELECT * FROM hafd.account_operations
        EXCEPT SELECT * FROM ( VALUES
                   ( 1, 1, hafd.operation_id(1, 1, 0) )
                 , ( 1, 2, hafd.operation_id(2, 1, 0) )
                 , ( 2, 1, hafd.operation_id(2, 1, 0) )
                 , ( 3, 1, hafd.operation_id(3, 1, 0) )
                 , ( 4, 1, hafd.operation_id(4, 1, 0) )
                 , ( 5, 1, hafd.operation_id(5, 1, 0) )
                 , ( 6, 1, hafd.operation_id(6, 1, 0) )
                 , ( 7, 2, hafd.operation_id(7, 1, 0) )
                 , ( 8, 2, hafd.operation_id(7, 1, 1) )
                 , ( 9, 3, hafd.operation_id(7, 1, 0) )
                 ) as pattern
    ) , 'Unexpected rows in the account_operations1';

    ASSERT ( SELECT COUNT(*) FROM hafd.account_operations ) = 10, 'Wrong number of rows';

END
$BODY$
;




