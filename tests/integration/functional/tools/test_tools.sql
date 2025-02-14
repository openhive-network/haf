CREATE SCHEMA IF NOT EXISTS test;
GRANT CREATE ON SCHEMA test TO PUBLIC;
GRANT ALL ON SCHEMA test TO PUBLIC;


SELECT hive.initialize_extension_data();

CREATE OR REPLACE FUNCTION test.unordered_arrays_equal(arr1 TEXT[], arr2 TEXT[])
RETURNS bool
LANGUAGE plpgsql
IMMUTABLE
AS
$$
BEGIN
    return (arr1 <@ arr2 and arr1 @> arr2);
END
$$
;

CREATE PROCEDURE test.check_eq(a anyelement, b anyelement, msg text DEFAULT 'Expected to be equal, but failed')
LANGUAGE plpgsql
AS
$BODY$
BEGIN
  IF a <> b THEN
    assert (SELECT FALSE), FORMAT(E'%s:\na: %s\nb: %s', msg, a, b);
  END IF;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION test.fill_with_blocks_data()
    RETURNS VOID
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
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

    INSERT INTO hafd.account_operations(account_id, transacting_account_id, account_op_seq_no, operation_id)
    VALUES
           ( 1, 1, 1, hafd.operation_id(1,1,0) )
         , ( 1, 1, 2, hafd.operation_id(2,1,0) )
         , ( 2, 2, 1, hafd.operation_id(2,1,0) )
         , ( 3, 3, 1, hafd.operation_id(3,1,0) )
         , ( 4, 4, 1, hafd.operation_id(4,1,0) )
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
    ( 4, 4, 1, hafd.operation_id(4,1,0),  1 ) -- block 4 (1)
         , ( 5, 5, 1, hafd.operation_id(5,1,0),  1 ) -- block 5 (1)
         , ( 6, 6, 1, hafd.operation_id(6,1,0),  1 ) -- block 6 (1)
         , ( 7, 7, 1, hafd.operation_id(7,1,0),  1 ) -- block 7(1), must be overriden by fork 2
         , ( 8, 8, 1, hafd.operation_id(7,1,0),  1 ) -- block 7(1), must be overriden by fork 2
         , ( 9, 9, 1, hafd.operation_id(7,1,2),  1 ) -- block 7(1), must be overriden by fork 2
         , ( 7, 7, 2, hafd.operation_id(9,1,0),  2 ) -- block 9 (2)
         , ( 9, 9, 2, hafd.operation_id(7,1,0),  2 ) -- block 7(2)
         , ( 9, 9, 3, hafd.operation_id(8,1,0),  2 ) -- block 8(2) -- block 8(3) has not operation
         , ( 4, 4, 2, hafd.operation_id(7,1,0),  2 ) -- block 7(2)
         , ( 10, 10, 2, hafd.operation_id(9,1,0), 2 ) -- block 9(2)
         , ( 10, 10, 3, hafd.operation_id(9,1,0), 3 ) -- block 9(3)
         , ( 11, 11, 3, hafd.operation_id(9,1,0), 3 ) -- block 9(3)
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

    UPDATE hafd.hive_state
    SET consistent_block = 5;
END;
$BODY$
;

