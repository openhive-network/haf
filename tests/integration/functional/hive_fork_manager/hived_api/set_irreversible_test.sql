
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'context', 'a' );

    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hafd.blocks
    VALUES
       ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( block_num, name, id )
    VALUES
           ( 1, 'u1', 1 )
         , ( 2, 'u2', 2 )
         , ( 3, 'u3', 3 )
         , ( 4, 'u4', 4 )
         , ( 5, 'u5', 5 )
    ;

    INSERT INTO hafd.transactions
    VALUES
           ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( 3, 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
         , ( 5, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.transactions_multisig
    VALUES
           ( '\xDEED10', '\xBAAD10' )
         , ( '\xDEED20', '\xBAAD20' )
         , ( '\xDEED30', '\xBAAD30' )
         , ( '\xDEED40', '\xBAAD40' )
         , ( '\xDEED50', '\xBAAD50' )
    ;

    INSERT INTO hafd.operations
    VALUES
           ( hafd.operation_id(1,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(2,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(3,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(4,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(5,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hafd.operation )
    ;

    INSERT INTO hafd.account_operations(account_id, account_op_seq_no, operation_id)
    VALUES
       ( 1, 1, hafd.operation_id(1,1,0) )
     , ( 1, 2, hafd.operation_id(2,1,0) )
     , ( 2, 1, hafd.operation_id(2,1,0) )
     , ( 3, 1, hafd.operation_id(3,1,0) )
     , ( 4, 1, hafd.operation_id(4,1,0) )
    ;

INSERT INTO hafd.applied_hardforks
VALUES
       ( 1, 1, hafd.operation_id(1,1,0) )
     , ( 2, 2, hafd.operation_id(2,1,0) )
     , ( 3, 3, hafd.operation_id(3,1,0) )
     , ( 4, 4, hafd.operation_id(4,1,0) )
     , ( 5, 5, hafd.operation_id(5,1,0) )
;

    INSERT INTO hafd.blocks_reversible
    VALUES
           ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:37-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 10, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:41-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w',1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD83', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 6, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 7, '\x4007', E'[]', '\x2157', 'STM65w',1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
    ;

    INSERT INTO hafd.accounts_reversible( block_num, name, id, fork_id)
    VALUES
           ( 4, 'u4_1',4 , 1 )
         , ( 5, 'u5_1',5 , 1 )
         , ( 6, 'u6_1',6 , 1 )
         , ( 7, 'u7_1',7 , 1 )
         , ( 10, 'u10_1',8 , 1 )
         , ( 7, 'u7_2', 9 , 2 )
         , ( 8, 'u8_2', 10 , 2 )
         , ( 9, 'u9_2', 11 , 2 )
         , ( 8, 'u8_3',12 , 3 )
         , ( 9, 'u9_3',13 , 3 )
         , ( 10, 'u10_3',14 , 3 )
    ;

    INSERT INTO hafd.transactions_reversible
    VALUES
           ( 4, 0::SMALLINT, '\xDEED40'::bytea, 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF'::bytea,  1 )
         , ( 5, 0::SMALLINT, '\xDEED55'::bytea, 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF'::bytea,  1 )
         , ( 6, 0::SMALLINT, '\xDEED60'::bytea, 101, 100, '2016-06-22 19:10:26-07'::timestamp, '\xBEEF'::bytea,  1 )
         , ( 7, 0::SMALLINT, '\xDEED70'::bytea, 101, 100, '2016-06-22 19:10:37-07'::timestamp, '\xBEEF'::bytea,  1 )
         , ( 10, 0::SMALLINT, '\xDEED11'::bytea, 101, 100, '2016-06-22 19:10:41-07'::timestamp, '\xBEEF'::bytea,  1 )
         , ( 7, 0::SMALLINT, '\xDEED70'::bytea, 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF'::bytea,  2 )
         , ( 8, 0::SMALLINT, '\xDEED80'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea,  2 )
         , ( 9, 0::SMALLINT, '\xDEED90'::bytea, 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF'::bytea,  2 )
         , ( 8, 0::SMALLINT, '\xDEED88'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea,  3 )
         , ( 9, 0::SMALLINT, '\xDEED99'::bytea, 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF'::bytea,  3 )
         , ( 10, 0::SMALLINT, '\xDEED1102'::bytea, 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF'::bytea, 3 )
    ;

    INSERT INTO hafd.transactions_multisig_reversible
    VALUES
           ( '\xDEED40'::bytea, '\xBEEF40'::bytea,  1 )
         , ( '\xDEED55'::bytea, '\xBEEF55'::bytea,  1 )
         , ( '\xDEED60'::bytea, '\xBEEF61'::bytea,  1 ) --block 6
         , ( '\xDEED70'::bytea, '\xBEEF7110'::bytea,  1 ) -- block 7
         , ( '\xDEED70'::bytea, '\xBEEF7120'::bytea,  1 ) -- block 7
         , ( '\xDEED70'::bytea, '\xBEEF7130'::bytea,  1 ) -- block 7 --must be abandon because of fork 2
         , ( '\xDEED11'::bytea, '\xBEEF7140'::bytea,  1 )
         , ( '\xDEED70'::bytea, '\xBEEF72'::bytea,  2 ) -- block 7
         , ( '\xDEED70'::bytea, '\xBEEF73'::bytea,  2 ) -- block 7
         , ( '\xDEED80'::bytea, '\xBEEF82'::bytea,  2 ) -- block 8
         , ( '\xDEED90'::bytea, '\xBEEF92'::bytea,  2 ) -- block 9
         , ( '\xDEED88'::bytea, '\xBEEF83'::bytea,  3 ) -- block 8
         , ( '\xDEED99'::bytea, '\xBEEF93'::bytea,  3 ) -- block 9
         , ( '\xDEED1102'::bytea, '\xBEEF13'::bytea,  3 ) -- block 10
    ;

    INSERT INTO hafd.operations_reversible(id, trx_in_block, op_pos, body_binary, fork_id)
    VALUES
           ( hafd.operation_id(4,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(5,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVEFIVE OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(6,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(7,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN0 OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(7,1,1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN01 OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(7,1,2), 0, 2, '{"type":"system_warning_operation","value":{"message":"SEVEN02 OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(7,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(7,1,1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(8,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EAIGHT2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(9,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(8,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hafd.operation, 3 )
         , ( hafd.operation_id(9,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hafd.operation, 3 )
         , ( hafd.operation_id(10,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hafd.operation, 3 )
    ;

    INSERT INTO hafd.account_operations_reversible
    VALUES
           ( 4, 1, hafd.operation_id(4,1,0),  1 ) -- block 4 (1)
         , ( 5, 1, hafd.operation_id(5,1,0),  1 ) -- block 5 (1)
         , ( 6, 1, hafd.operation_id(6,1,0),  1 ) -- block 6 (1)
         , ( 7, 1, hafd.operation_id(7,1,0),  1 ) -- block 7(1), must be overriden by fork 2
         , ( 8, 1, hafd.operation_id(7,1,0),  1 ) -- block 7(1), must be overriden by fork 2
         , ( 9, 1, hafd.operation_id(7,1,2),  1 ) -- block 7(1), must be overriden by fork 2
         , ( 7, 2, hafd.operation_id(9,1,0),  2 ) -- block 9 (2)
         , ( 9, 2, hafd.operation_id(7,1,0),  2 ) -- block 7(2)
         , ( 9, 3, hafd.operation_id(8,1,0),  2 ) -- block 8(2) -- block 8(3) has not operation
         , ( 4, 2, hafd.operation_id(7,1,0),  2 ) -- block 7(2)
         , ( 10, 2, hafd.operation_id(9,1,0), 2 ) -- block 9(2)
         , ( 10, 3, hafd.operation_id(9,1,0), 3 ) -- block 9(3)
         , ( 11, 3, hafd.operation_id(9,1,0), 3 ) -- block 9(3)
    ;

INSERT INTO hafd.applied_hardforks_reversible
VALUES
       ( 4, 4, hafd.operation_id(4,1,0), 1 )
     , ( 5, 5, hafd.operation_id(5,1,0), 1 )
     , ( 6, 6, hafd.operation_id(6,1,0), 1 )
     , ( 7, 7, hafd.operation_id(7,1,0), 1 ) -- must be abandon because of fork2
     , ( 8, 7, hafd.operation_id(7,1,1), 1 ) -- must be abandon because of fork2
     , ( 9, 7, hafd.operation_id(7,1,2), 1 ) -- must be abandon because of fork2
     , ( 7, 7, hafd.operation_id(7,1,0), 2 )
     , ( 8, 7, hafd.operation_id(7,1,1), 2 )
     , ( 9, 8, hafd.operation_id(8,1,0), 2 )
     , ( 10, 9, hafd.operation_id(9,1,0), 2 )
     , ( 9, 8, hafd.operation_id(8,1,0), 3 )
     , ( 10, 9, hafd.operation_id(9,1,0), 3 )
     , ( 11, 10, hafd.operation_id(10,1,0), 3 )
;


    UPDATE hafd.contexts SET fork_id = 2, irreversible_block = 8, current_block_num = 8;
    -- SUMMARY:
    --We have 3 forks: 1 (blocks: 4,5,6),2 (blocks: 7,8,9) ,3 (blocks: 8,9, 10), moreover block 1,2,3,4 are
    --in set of irreversible blocks. There is one context which is working on 8 block on fork 2, and has information
    --that block nr 8 is last known irreversible block.

END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- block 8 from current top fork (nr 3 ) become irreversible
    PERFORM hive.set_irreversible( 8 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS( SELECT * FROM hafd.blocks ), 'No blocks';
    ASSERT NOT EXISTS (
        SELECT * FROM hafd.blocks WHERE num > 0
        EXCEPT SELECT * FROM ( VALUES
                   ( 1, '\xBADD10'::bytea, '\xCAFE10'::bytea, '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 2, '\xBADD20'::bytea, '\xCAFE20'::bytea, '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 3, '\xBADD30'::bytea, '\xCAFE30'::bytea, '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 4, '\xBADD40'::bytea, '\xCAFE40'::bytea, '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 5, '\xBADD50'::bytea, '\xCAFE50'::bytea, '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 6, '\xBADD60'::bytea, '\xCAFE60'::bytea, '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 7, '\xBADD70'::bytea, '\xCAFE70'::bytea, '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 8, '\xBADD83'::bytea, '\xCAFE80'::bytea, '2016-06-22 19:10:30-07'::timestamp, 6, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 ) as pattern
    ) , 'Unexpected rows in hafd.blocks';


    ASSERT EXISTS( SELECT * FROM hafd.blocks_reversible ), 'No reversible blocks';

    ASSERT NOT EXISTS (
        SELECT * FROM hafd.blocks_reversible
        EXCEPT SELECT * FROM ( VALUES
              ( 7, '\xBADD70'::bytea, '\xCAFE70'::bytea, '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
            , ( 8, '\xBADD80'::bytea, '\xCAFE80'::bytea, '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
            , ( 9, '\xBADD90'::bytea, '\xCAFE90'::bytea, '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
            , ( 8, '\xBADD83'::bytea, '\xCAFE80'::bytea, '2016-06-22 19:10:30-07'::timestamp, 6, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
            , ( 9, '\xBADD90'::bytea, '\xCAFE90'::bytea, '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
            , ( 10, '\xBADD1A'::bytea, '\xCAFE1A'::bytea, '2016-06-22 19:10:32-07'::timestamp, 7, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
        ) as pattern
    ) , 'Unexpected rows in hafd.blocks_reversible';

    ASSERT EXISTS( SELECT * FROM hafd.accounts_reversible ), 'No accounts reversible';

    ASSERT ( SELECT COUNT(*) FROM hafd.accounts WHERE id >= 0 ) = 8, 'Wrong number of accounts';
    ASSERT NOT EXISTS (
        SELECT block_num, name, id FROM hafd.accounts WHERE id >= 0
        EXCEPT SELECT * FROM ( VALUES
                   ( 1, 'u1', 1 )
                 , ( 2, 'u2', 2 )
                 , ( 3, 'u3', 3 )
                 , ( 4, 'u4', 4 )
                 , ( 5, 'u5', 5 )
                 , ( 6, 'u6_1',6 )
                 , ( 7, 'u7_2', 9 )
                 , ( 8, 'u8_3', 12 )
                 ) as pattern
    ) , 'Unexpected rows in hafd.accounts';

    ASSERT NOT EXISTS (
        SELECT block_num, name, id, fork_id FROM hafd.accounts_reversible
        EXCEPT SELECT * FROM ( VALUES
               ( 7, 'u7_2', 9 , 2 )
             , ( 8, 'u8_2', 10 , 2 )
             , ( 9, 'u9_2', 11 , 2 )
             , ( 8, 'u8_3',12 , 3 )
             , ( 9, 'u9_3',13 , 3 )
             , ( 10, 'u10_3',14 , 3 )
        ) as pattern
    ) , 'Unexpected rows in hafd.accounts_reversible';

    ASSERT EXISTS( SELECT * FROM hafd.transactions ), 'No transactions';

    ASSERT NOT EXISTS (
        SELECT * FROM hafd.transactions
        EXCEPT SELECT * FROM ( VALUES
                   ( 1, 0::SMALLINT, '\xDEED10'::bytea, 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF'::bytea )
                 , ( 2, 0::SMALLINT, '\xDEED20'::bytea, 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF'::bytea )
                 , ( 3, 0::SMALLINT, '\xDEED30'::bytea, 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF'::bytea )
                 , ( 4, 0::SMALLINT, '\xDEED40'::bytea, 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF'::bytea )
                 , ( 5, 0::SMALLINT, '\xDEED50'::bytea, 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF'::bytea )
                 , ( 6, 0::SMALLINT, '\xDEED60'::bytea, 101, 100, '2016-06-22 19:10:26-07'::timestamp, '\xBEEF'::bytea )
                 , ( 7, 0::SMALLINT, '\xDEED70'::bytea, 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF'::bytea )
                 , ( 7, 1::SMALLINT, '\xDEED70B1'::bytea, 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF'::bytea )
                 , ( 8, 0::SMALLINT, '\xDEED88'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea )
                 ) as pattern
    ) , 'Unexpected rows in hafd.transactions';

    ASSERT EXISTS( SELECT * FROM hafd.transactions_multisig ), 'No transactions signatures';

    ASSERT NOT EXISTS (
        SELECT * FROM hafd.transactions_multisig
        EXCEPT SELECT * FROM ( VALUES
              ( '\xDEED10'::bytea, '\xBAAD10'::bytea )
            , ( '\xDEED20'::bytea, '\xBAAD20'::bytea )
            , ( '\xDEED30'::bytea, '\xBAAD30'::bytea )
            , ( '\xDEED40'::bytea, '\xBAAD40'::bytea )
            , ( '\xDEED50'::bytea, '\xBAAD50'::bytea )
            , ( '\xDEED60'::bytea, '\xBEEF61'::bytea )
            , ( '\xDEED70'::bytea, '\xBEEF72'::bytea )
            , ( '\xDEED70'::bytea, '\xBEEF73'::bytea )
            , ( '\xDEED88'::bytea, '\xBEEF83'::bytea )
         ) as pattern
    ) , 'Unexpected rows in hafd.transactions_multisig';

    ASSERT EXISTS( SELECT * FROM hafd.operations ), 'No operations';

    ASSERT NOT EXISTS (
        SELECT id, trx_in_block, op_pos, body_binary FROM hafd.operations
        EXCEPT SELECT * FROM ( VALUES
              ( hafd.operation_id(1,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(2,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(3,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(4,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(5,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(6,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(7,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(7,1,1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(8,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hafd.operation )
        ) as pattern
    ) , 'Unexpected rows in hafd.operations';

    ASSERT EXISTS( SELECT * FROM hafd.transactions_reversible ), 'No reversible transactions';


    ASSERT NOT EXISTS (
        SELECT * FROM hafd.transactions_reversible
        EXCEPT SELECT * FROM ( VALUES
               ( 7, 0::SMALLINT, '\xDEED70'::bytea, 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF'::bytea,  2 )
             , ( 8, 0::SMALLINT, '\xDEED80'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea,  2 )
             , ( 9, 0::SMALLINT, '\xDEED90'::bytea, 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF'::bytea,  2 )
             , ( 8, 0::SMALLINT, '\xDEED88'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea,  3 )
             , ( 9, 0::SMALLINT, '\xDEED99'::bytea, 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF'::bytea,  3 )
             , ( 10, 0::SMALLINT, '\xDEED1102'::bytea, 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF'::bytea, 3 )
        ) as pattern
    ) , 'Unexpected rows in hafd.transactions_reversible';

    ASSERT EXISTS( SELECT * FROM hafd.transactions_multisig_reversible ), 'No reversible signatures';

    ASSERT NOT EXISTS (
    SELECT * FROM hafd.transactions_multisig_reversible
    EXCEPT SELECT * FROM ( VALUES
           ( '\xDEED70'::bytea, '\xBEEF72'::bytea,  2 ) -- block 7
         , ( '\xDEED70'::bytea, '\xBEEF73'::bytea,  2 ) -- block 7
         , ( '\xDEED80'::bytea, '\xBEEF82'::bytea,  2 ) -- block 8
         , ( '\xDEED90'::bytea, '\xBEEF92'::bytea,  2 ) -- block 9
         , ( '\xDEED88'::bytea, '\xBEEF83'::bytea,  3 ) -- block 8
         , ( '\xDEED99'::bytea, '\xBEEF93'::bytea,  3 ) -- block 9
         , ( '\xDEED1102'::bytea, '\xBEEF13'::bytea,  3 ) -- block 10
    ) as pattern
    ) , 'Unexpected rows in hafd.transactions_multisig_reversible';

    ASSERT EXISTS( SELECT * FROM hafd.operations_reversible ), 'No reversible oprations';

    ASSERT NOT EXISTS (
    SELECT id, trx_in_block, op_pos, body_binary, fork_id FROM hafd.operations_reversible
    EXCEPT SELECT * FROM ( VALUES
           ( hafd.operation_id(7,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(7,1,1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(8,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EAIGHT2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(9,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(8,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hafd.operation, 3 )
         , ( hafd.operation_id(9,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hafd.operation, 3 )
         , ( hafd.operation_id(10,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hafd.operation, 3 )
    ) as pattern
    ), 'Unexpected rows in hafd.operations_reversible'
    ;

    ASSERT NOT EXISTS (
    SELECT * FROM hafd.account_operations
    EXCEPT SELECT * FROM ( VALUES
                  ( 1, 1, hafd.operation_id(1,1,0))
                , ( 1, 2, hafd.operation_id(2,1,0))
                , ( 2, 1, hafd.operation_id(2,1,0))
                , ( 3, 1, hafd.operation_id(3,1,0))
                , ( 4, 1, hafd.operation_id(4,1,0))
                , ( 6, 1, hafd.operation_id(6,1,0)) -- block 6 (1)
                , ( 4, 2, hafd.operation_id(7,1,0)) -- block 7(2)
                , ( 9, 2, hafd.operation_id(7,1,0)) -- block 7(2)
             ) as pattern
    ) , 'Unexpected rows in the account_operations';
    ASSERT ( SELECT COUNT(*) FROM hafd.account_operations ) = 8, 'Wrong number of hive account_operations';

    ASSERT EXISTS( SELECT * FROM hafd.applied_hardforks ), 'No applied_hardforks';

    ASSERT NOT EXISTS (
        SELECT * FROM hafd.applied_hardforks
        EXCEPT SELECT * FROM ( VALUES
       ( 1, 1, hafd.operation_id(1,1,0) )
     , ( 2, 2, hafd.operation_id(2,1,0) )
     , ( 3, 3, hafd.operation_id(3,1,0) )
     , ( 4, 4, hafd.operation_id(4,1,0) )
     , ( 5, 5, hafd.operation_id(5,1,0) )
     , ( 6, 6, hafd.operation_id(6,1,0) )
     , ( 7, 7, hafd.operation_id(7,1,0) )
     , ( 8, 7, hafd.operation_id(7,1,1) )
     , ( 9, 8, hafd.operation_id(8,1,0) )
        ) as pattern
    ) , 'Unexpected rows in hafd.applied_hardforks';

    ASSERT EXISTS( SELECT * FROM hafd.applied_hardforks_reversible ), 'No reversible applied_hardforks';


    ASSERT NOT EXISTS (
        SELECT * FROM hafd.applied_hardforks_reversible
        EXCEPT SELECT * FROM ( VALUES
       ( 7, 7, hafd.operation_id(7,1,0), 2 )
     , ( 8, 7, hafd.operation_id(7,1,1), 2 )
     , ( 9, 8, hafd.operation_id(8,1,0), 2 )
     , ( 10, 9, hafd.operation_id(9,1,0), 2 )
     , ( 9, 8, hafd.operation_id(8,1,0), 3 )
     , ( 10, 9, hafd.operation_id(9,1,0), 3 )
     , ( 11, 10, hafd.operation_id(10,1,0), 3 )
        ) as pattern
    ) , 'Unexpected rows in hafd.applied_hardforks_reversible';
    
END;
$BODY$
;




