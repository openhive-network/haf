
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );

    INSERT INTO hive.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hive.operation_types
    VALUES ( 0, 'OP 0', FALSE )
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

    INSERT INTO hive.transactions_multisig_reversible
    VALUES
           ( 4, '\xDEED40'::bytea, '\xBEEF40'::bytea,  1 )
         , ( 5, '\xDEED55'::bytea, '\xBEEF55'::bytea,  1 )
         , ( 6, '\xDEED60'::bytea, '\xBEEF61'::bytea,  1 ) --block 6
         , ( 7, '\xDEED70'::bytea, '\xBEEF7110'::bytea,  1 ) -- block 7
         , ( 7, '\xDEED70'::bytea, '\xBEEF7120'::bytea,  1 ) -- block 7
         , ( 7, '\xDEED70'::bytea, '\xBEEF7130'::bytea,  1 ) -- block 7 --must be abandon because of fork 2
         , ( 1, '\xDEED11'::bytea, '\xBEEF7140'::bytea,  1 )
         , ( 7, '\xDEED70'::bytea, '\xBEEF72'::bytea,  2 ) -- block 7
         , ( 7, '\xDEED70'::bytea, '\xBEEF73'::bytea,  2 ) -- block 7
         , ( 8, '\xDEED80'::bytea, '\xBEEF82'::bytea,  2 ) -- block 8
         , ( 9, '\xDEED90'::bytea, '\xBEEF92'::bytea,  2 ) -- block 9
         , ( 8, '\xDEED88'::bytea, '\xBEEF83'::bytea,  3 ) -- block 8
         , ( 9, '\xDEED99'::bytea, '\xBEEF93'::bytea,  3 ) -- block 9
         , ( 10, '\xDEED1102'::bytea, '\xBEEF13'::bytea,  3 ) -- block 10
    ;

    INSERT INTO hive.operations_reversible(id, block_num, trx_in_block, op_pos, op_type_id, timestamp, body_binary, fork_id)
    VALUES
           ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hive.operation, 1 )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"FIVEFIVE OPERATION"}}' :: jsonb :: hive.operation, 1 )
         , ( 6, 6, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb :: hive.operation, 1 )
         , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN0 OPERATION"}}' :: jsonb :: hive.operation, 1 )
         , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN01 OPERATION"}}' :: jsonb :: hive.operation, 1 )
         , ( 9, 7, 0, 2, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN02 OPERATION"}}' :: jsonb :: hive.operation, 1 )
         , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hive.operation, 2 )
         , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hive.operation, 2 )
         , ( 9, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"EAIGHT2 OPERATION"}}' :: jsonb :: hive.operation, 2 )
         , ( 10, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hive.operation, 2 )
         , ( 9, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hive.operation, 3 )
         , ( 10, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hive.operation, 3 )
         , ( 11, 10, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hive.operation, 3 )
    ;

INSERT INTO hive.applied_hardforks_reversible
VALUES
       ( 4, 4, 4, 1 )
     , ( 5, 5, 5, 1 )
     , ( 6, 6, 6, 1 )
     , ( 7, 7, 7, 1 ) -- must be abandon because of fork2
     , ( 8, 7, 8, 1 ) -- must be abandon because of fork2
     , ( 9, 7, 9, 1 ) -- must be abandon because of fork2
     , ( 7, 7, 7, 2 )
     , ( 8, 7, 8, 2 )
     , ( 9, 8, 9, 2 )
     , ( 10, 9, 10, 2 )
     , ( 9, 8, 9, 3 )
     , ( 10, 9, 10, 3 )
     , ( 11, 10, 11, 3 )
;

    INSERT INTO hive.account_operations_reversible
    VALUES
       ( 4, 4, 1, 4, 1, 1 )
     , ( 5, 5, 1, 5, 1, 1 )
     , ( 6, 6, 1, 6, 1, 1 )
     , ( 7, 7, 1, 7, 1, 1 ) -- must be overriden by fork 2
     , ( 7, 8, 1, 7, 1, 1 ) -- must be overriden by fork 2
     , ( 7, 9, 1, 9, 1, 1 ) -- must be overriden by fork 2
     , ( 7, 7, 2, 7, 1, 2 )
     , ( 7, 8, 2, 8, 1, 2 ) -- will be abandoned since fork 3 doesn not have this account operation
     , ( 8, 9, 2, 9, 1, 2 )
     , ( 7, 9, 3, 8, 1, 2 )
     , ( 9, 10, 2, 10, 1, 2 )
     , ( 8, 9, 3, 9, 1, 3 )
     , ( 9, 10, 3, 10, 1, 3 )
     , ( 10, 11, 3, 10, 1, 3 )
;


    UPDATE hive.contexts SET fork_id = 2, irreversible_block = 8, current_block_num = 8;
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
    PERFORM hive.refresh_irreversible_block_for_all_contexts( 8 );
    PERFORM hive.remove_obsolete_reversible_data( 8 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS( SELECT * FROM hive.blocks_reversible ), 'No reversible blocks';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.blocks_reversible
        EXCEPT SELECT * FROM ( VALUES
              ( 10, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:41-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
            , ( 8, '\xBADD80'::bytea, '\xCAFE80'::bytea, '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
            , ( 9, '\xBADD90'::bytea, '\xCAFE90'::bytea, '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
            , ( 8, '\xBADD80'::bytea, '\xCAFE80'::bytea, '2016-06-22 19:10:30-07'::timestamp, 7, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
            , ( 9, '\xBADD90'::bytea, '\xCAFE90'::bytea, '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
            , ( 10, '\xBADD1A'::bytea, '\xCAFE1A'::bytea, '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
        ) as pattern
    ) , 'Unexpected rows in hive.blocks_reversible';

    ASSERT EXISTS( SELECT * FROM hive.accounts_reversible ), 'No reversible accounts';

    ASSERT NOT EXISTS (
        SELECT block_num, name, id, fork_id FROM hive.accounts_reversible
        EXCEPT SELECT * FROM ( VALUES
            ( 10, 'u10_1',5 , 1 )
          , ( 8, 'u8_2', 7 , 2 )
          , ( 9, 'u9_2', 8 , 2 )
          , ( 8, 'u8_2',9 , 3 )
          , ( 9, 'u9_3',10 , 3 )
          , ( 10, 'u10_3',11 , 3 )
        ) as pattern
    ) , 'Unexpected rows in hive.accounts_reversible';

    ASSERT EXISTS( SELECT * FROM hive.transactions_reversible ), 'No reversible transactions';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.transactions_reversible
        EXCEPT SELECT * FROM ( VALUES
               ( 10, 0::SMALLINT, '\xDEED11'::bytea, 101, 100, '2016-06-22 19:10:41-07'::timestamp, '\xBEEF'::bytea,  1 )
             , ( 8, 0::SMALLINT, '\xDEED80'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea,  2 )
             , ( 9, 0::SMALLINT, '\xDEED90'::bytea, 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF'::bytea,  2 )
             , ( 8, 0::SMALLINT, '\xDEED88'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea,  3 )
             , ( 9, 0::SMALLINT, '\xDEED99'::bytea, 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF'::bytea,  3 )
             , ( 10, 0::SMALLINT, '\xDEED1102'::bytea, 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF'::bytea, 3 )
        ) as pattern
    ) , 'Unexpected rows in hive.transactions_reversible';

    ASSERT EXISTS( SELECT * FROM hive.transactions_multisig_reversible ), 'No reversible signatures';

    ASSERT NOT EXISTS (
    SELECT * FROM hive.transactions_multisig_reversible
    EXCEPT SELECT * FROM ( VALUES
           ( '\xDEED11'::bytea, '\xBEEF7140'::bytea,  1 )
         , ( '\xDEED80'::bytea, '\xBEEF82'::bytea,  2 ) -- block 8
         , ( '\xDEED90'::bytea, '\xBEEF92'::bytea,  2 ) -- block 9
         , ( '\xDEED88'::bytea, '\xBEEF83'::bytea,  3 ) -- block 8
         , ( '\xDEED99'::bytea, '\xBEEF93'::bytea,  3 ) -- block 9
         , ( '\xDEED1102'::bytea, '\xBEEF13'::bytea,  3 ) -- block 10
    ) as pattern
    ) , 'Unexpected rows in hive.transactions_multisig_reversible';


    ASSERT EXISTS( SELECT * FROM hive.operations_reversible ), 'No reversible oprations';

    ASSERT NOT EXISTS (
    SELECT id, block_num, trx_in_block, op_pos, op_type_id, timestamp, body_binary, fork_id FROM hive.operations_reversible
    EXCEPT SELECT * FROM ( VALUES
           ( 9, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"EAIGHT2 OPERATION"}}' :: jsonb :: hive.operation, 2 )
         , ( 10, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hive.operation, 2 )
         , ( 9, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hive.operation, 3 )
         , ( 10, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hive.operation, 3 )
         , ( 11, 10, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hive.operation, 3 )
    ) as pattern
    ), 'Unexpected rows in hive.operations_reversible'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive.account_operations_reversible ) = 3, 'Wrong number of account_operations_reversible';
    ASSERT NOT EXISTS (
    SELECT * FROM hive.account_operations_reversible
    EXCEPT SELECT * FROM ( VALUES
          ( 8, 9, 2, 9, 1, 2 )
        , ( 9, 10, 2, 10, 1, 2 )
        , ( 8, 9, 3, 9, 1, 3 )
        , ( 9, 10, 3, 10, 1, 3 )
        , ( 10, 11, 3, 10, 1, 3 )
    ) as pattern
    ), 'Unexpected rows in hive.account_operations_reversible'
    ;

    ASSERT EXISTS( SELECT * FROM hive.applied_hardforks_reversible ), 'No reversible applied_hardforks';
    ASSERT NOT EXISTS (
        SELECT * FROM hive.applied_hardforks_reversible
        EXCEPT SELECT * FROM ( VALUES
        ( 9, 8, 9, 2 )
      , ( 10, 9, 10, 2 )
      , ( 9, 8, 9, 3 )
      , ( 10, 9, 10, 3 )
      , ( 11, 10, 11, 3 )
        ) as pattern
    ) , 'Unexpected rows in hive.applied_hardforks_reversible';

END;
$BODY$
;




