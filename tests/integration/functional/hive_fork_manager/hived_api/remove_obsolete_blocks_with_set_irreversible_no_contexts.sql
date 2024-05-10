
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hive.operation_types
    VALUES (0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive.blocks_reversible
    VALUES
           ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD71', '\xCAFE71', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 10, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:41-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 7, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
    ;

    INSERT INTO hive.accounts_reversible( block_num, name, id, fork_id)
    VALUES
           ( 4, 'u4_1',1 , 1 )
         , ( 5, 'u5_1',2 , 1 )
         , ( 6, 'u6_1',3 , 1 )
         , ( 7, 'u7_1',4 , 1 )
         , ( 10, 'u10_1',5 , 1 )
         , ( 7, 'u7_2', 6 , 2 )
         , ( 8, 'u8_2', 7 , 2 )
         , ( 9, 'u9_2', 8 , 2 )
         , ( 8, 'u8_2',9 , 3 )
         , ( 9, 'u9_3',10 , 3 )
         , ( 10, 'u10_3',11 , 3 )
    ;

    INSERT INTO hive.transactions_reversible
    VALUES
           ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF',  1 )
         , ( 5, 0::SMALLINT, '\xDEED55', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF',  1 )
         , ( 6, 0::SMALLINT, '\xDEED60', 101, 100, '2016-06-22 19:10:26-07'::timestamp, '\xBEEF',  1 )
         , ( 7, 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:37-07'::timestamp, '\xBEEF',  1 )
         , ( 10, 0::SMALLINT, '\xDEED11', 101, 100, '2016-06-22 19:10:41-07'::timestamp, '\xBEEF',  1 )
         , ( 7, 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF',  2 )
         , ( 8, 0::SMALLINT, '\xDEED80', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF',  2 )
         , ( 9, 0::SMALLINT, '\xDEED90', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF',  2 )
         , ( 8, 0::SMALLINT, '\xDEED88', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF',  3 )
         , ( 9, 0::SMALLINT, '\xDEED99', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF',  3 )
         , ( 10, 0::SMALLINT, '\xDEED1102', 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF', 3 )
    ;

    INSERT INTO hive.transactions_multisig_reversible
    VALUES
           ( '\xDEED40', '\xBEEF40',  1 )
         , ( '\xDEED55', '\xBEEF55',  1 )
         , ( '\xDEED60', '\xBEEF61',  1 )
         , ( '\xDEED70', '\xBEEF7110',  1 ) --must be abandon because of fork 2
         , ( '\xDEED70', '\xBEEF7120',  1 ) --must be abandon because of fork 2
         , ( '\xDEED70', '\xBEEF7130',  1 ) --must be abandon because of fork 2
         , ( '\xDEED11', '\xBEEF7140',  1 )
         , ( '\xDEED70', '\xBEEF72',  2 ) -- block 7
         , ( '\xDEED70', '\xBEEF73',  2 ) -- block 7
         , ( '\xDEED80', '\xBEEF82',  2 ) -- block 8
         , ( '\xDEED90', '\xBEEF92',  2 ) -- block 9
         , ( '\xDEED88', '\xBEEF83',  3 ) -- block 8
         , ( '\xDEED99', '\xBEEF93',  3 ) -- block 9
         , ( '\xDEED1102', '\xBEEF13',  3 ) -- block 10
    ;

    INSERT INTO hive.operations_reversible(id, trx_in_block, op_pos, timestamp, body_binary, fork_id)
    VALUES
    ( hive.operation_id(4,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hive.operation, 1 )
         , ( hive.operation_id(5,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"FIVEFIVE OPERATION"}}' :: jsonb :: hive.operation, 1 )
         , ( hive.operation_id(6,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb :: hive.operation, 1 )
         , ( hive.operation_id(7,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN0 OPERATION"}}' :: jsonb :: hive.operation, 1 ) -- must be abandon because of fork2
         , ( hive.operation_id(7,1,1), 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN01 OPERATION"}}' :: jsonb :: hive.operation, 1 ) -- must be abandon because of fork2
         , ( hive.operation_id(7,1,2), 0, 2, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN02 OPERATION"}}' :: jsonb :: hive.operation, 1 ) -- must be abandon because of fork2
         , ( hive.operation_id(7,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hive.operation, 2 )
         , ( hive.operation_id(7,1,1), 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hive.operation, 2 )
         , ( hive.operation_id(8,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"EAIGHT2 OPERATION"}}' :: jsonb :: hive.operation, 2 )
         , ( hive.operation_id(9,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hive.operation, 2 )
         , ( hive.operation_id(8,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hive.operation, 3 )
         , ( hive.operation_id(9,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hive.operation, 3 )
         , ( hive.operation_id(10,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hive.operation, 3 )
    ;

    INSERT INTO hive.account_operations_reversible
    VALUES
    ( 4, 4, 1, hive.operation_id(4,1,0), 1, 1 )
         , ( 5, 5, 1, hive.operation_id(5,1,0), 1, 1 )
         , ( 6, 6, 1, hive.operation_id(6,1,0), 1, 1 )
         , ( 7, 7, 1, hive.operation_id(7,1,0), 1, 1 ) -- must be overriden by fork 2
         , ( 7, 8, 1, hive.operation_id(7,1,1), 1, 1 ) -- must be overriden by fork 2
         , ( 7, 9, 1, hive.operation_id(7,1,2), 1, 1 ) -- must be overriden by fork 2
         , ( 7, 7, 2, hive.operation_id(7,1,0), 1, 2 )
         , ( 7, 8, 2, hive.operation_id(7,1,1), 1, 2 ) -- will be abandoned since fork 3 doesn not have this account operation
         , ( 8, 9, 2, hive.operation_id(8,1,0), 1, 2 )
         , ( 7, 9, 3, hive.operation_id(7,1,0), 1, 2 )
         , ( 9, 10, 2, hive.operation_id(9,1,0), 1, 2 )
         , ( 8, 9, 3, hive.operation_id(8,1,0), 1, 3 )
         , ( 9, 10, 3, hive.operation_id(9,1,0), 1, 3 )
         , ( 10, 11, 3, hive.operation_id(10,1,0), 1, 3 )
    ;

    -- SUMMARY:
    --We have 3 forks: 1 (blocks: 4,5,6),2 (blocks: 7,8,9) ,3 (blocks: 8,9, 10), moreover block 1,2,3,4 are
    --in set of irreversible blocks.
    INSERT INTO hive.applied_hardforks_reversible
    VALUES
           ( 4, 4, hive.operation_id(4,1,0), 1 )
         , ( 5, 5, hive.operation_id(5,1,0), 1 )
         , ( 6, 6, hive.operation_id(6,1,0), 1 )
         , ( 7, 7, hive.operation_id(7,1,0), 1 ) -- must be abandon because of fork2
         , ( 8, 7, hive.operation_id(7,1,1), 1 ) -- must be abandon because of fork2
         , ( 9, 7, hive.operation_id(7,1,2), 1 ) -- must be abandon because of fork2
         , ( 7, 7, hive.operation_id(7,1,0), 2 )
         , ( 8, 7, hive.operation_id(7,1,1), 2 )
         , ( 9, 8, hive.operation_id(8,1,0) , 2 )
         , ( 10, 9, hive.operation_id(9,1,0), 2 )
         , ( 9, 8, hive.operation_id(8,1,0), 3 )
         , ( 10, 9, hive.operation_id(9,1,0), 3 )
         , ( 11, 10, hive.operation_id(10,1,0), 3 )
    ;


END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- block 8 from current top fork (nr 3 ) become irreversible
    PERFORM hive.remove_obsolete_reversible_data( 8 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Because 'context' is processing block 8 on fork 2 we can only remove older blocks and forks, thus beacuse
    -- we don't want to lock whole tables shared between an application and the hived.

    ASSERT EXISTS( SELECT * FROM hive.blocks_reversible ), 'No reversible blocks';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.blocks_reversible
        EXCEPT SELECT * FROM ( VALUES
           ( 10, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:41-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80'::bytea, '\xCAFE80'::bytea, '2016-06-22 19:10:30-07'::timestamp, 7, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 9, '\xBADD90'::bytea, '\xCAFE90'::bytea, '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 10, '\xBADD1A'::bytea, '\xCAFE1A'::bytea, '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
        ) as pattern
    ) , 'Unexpected rows in hive.blocks_reversible';

    ASSERT NOT EXISTS (
    SELECT block_num, name, id, fork_id FROM hive.accounts_reversible
    EXCEPT SELECT * FROM ( VALUES
       ( 10, 'u10_1',5 , 1 )
     , ( 7, 'u7_2', 6 , 2 )
     , ( 8, 'u8_2', 7 , 2 )
     , ( 9, 'u9_2', 8 , 2 )
     , ( 8, 'u8_2',9 , 3 )
     , ( 9, 'u9_3',10 , 3 )
     , ( 10, 'u10_3',11 , 3 )
    ) as pattern
    ) , 'Unexpected rows in hive.accounts_reversible';

    ASSERT EXISTS( SELECT * FROM hive.accounts_reversible ), 'No reversible accounts';

    ASSERT EXISTS( SELECT * FROM hive.transactions_reversible ), 'No reversible transactions';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.transactions_reversible
        EXCEPT SELECT * FROM ( VALUES
           ( 10, 0::SMALLINT, '\xDEED11', 101, 100, '2016-06-22 19:10:41-07'::timestamp, '\xBEEF',  1 )
         , ( 8, 0::SMALLINT, '\xDEED80', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF',  2 )
         , ( 9, 0::SMALLINT, '\xDEED90', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF',  2 )
         , ( 8, 0::SMALLINT, '\xDEED88'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea,  3 )
         , ( 9, 0::SMALLINT, '\xDEED99'::bytea, 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF'::bytea,  3 )
         , ( 10, 0::SMALLINT, '\xDEED1102'::bytea, 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF'::bytea, 3 )
        ) as pattern
    ) , 'Unexpected rows in hive.transactions_reversible';

    ASSERT EXISTS( SELECT * FROM hive.transactions_multisig_reversible ), 'No reversible signatures';

    ASSERT NOT EXISTS (
    SELECT * FROM hive.transactions_multisig_reversible
    EXCEPT SELECT * FROM ( VALUES
           ( '\xDEED11', '\xBEEF7140',  1 ) -- block 10 , fork 1
         , ( '\xDEED80', '\xBEEF82',  2 )  -- block 8 f2
         , ( '\xDEED90', '\xBEEF92',  2 ) -- block 9 f2
         , ( '\xDEED88'::bytea, '\xBEEF83'::bytea,  3 ) -- block 8
         , ( '\xDEED99'::bytea, '\xBEEF93'::bytea,  3 ) -- block 9
         , ( '\xDEED1102'::bytea, '\xBEEF13'::bytea,  3 ) -- block 10
    ) as pattern
    ) , 'Unexpected rows in hive.transactions_multisig_reversible';

    ASSERT EXISTS( SELECT * FROM hive.operations_reversible ), 'No reversible operations';

    ASSERT NOT EXISTS (
    SELECT id, trx_in_block, op_pos, timestamp, body_binary, fork_id FROM hive.operations_reversible
    EXCEPT SELECT * FROM ( VALUES
           ( hive.operation_id(8,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"EAIGHT2 OPERATION"}}' :: jsonb :: hive.operation, 2 )
         , ( hive.operation_id(9,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hive.operation, 2 )
         , ( hive.operation_id(8,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hive.operation, 3 )
         , ( hive.operation_id(9,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hive.operation, 3 )
         , ( hive.operation_id(10,1,0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hive.operation, 3 )
    ) as pattern
    ), 'Unexpected rows in hive.operations_reversible'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive.account_operations_reversible ) = 2, 'Wrong number of account_operations';
    ASSERT NOT EXISTS (
    SELECT * FROM hive.account_operations_reversible
    EXCEPT SELECT * FROM ( VALUES
               ( 9, 10, 3, hive.operation_id(9,1,0), 1, 3 )
             , ( 10, 11, 3, hive.operation_id(10,1,0), 1, 3 )
        ) as pattern
    ), 'Unexpected rows in hive.account_operations_reversible'
    ;

    ASSERT EXISTS( SELECT * FROM hive.applied_hardforks_reversible ), 'No reversible applied_hardforks';
    ASSERT NOT EXISTS (
        SELECT * FROM hive.applied_hardforks_reversible
        EXCEPT SELECT * FROM ( VALUES
       ( 10, 9, hive.operation_id(9,1,0), 3 )
     , ( 11, 10, hive.operation_id(10,1,0), 3 )
        ) as pattern
    ) , 'Unexpected rows in hive.applied_hardforks_reversible';

END;
$BODY$
;


