
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'context', _schema => 'a', _is_forking =>FALSE );

    INSERT INTO hive.operation_types
    VALUES ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hive.blocks
    VALUES
        ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.blocks_reversible
    VALUES
        ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
        , ( 5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
        , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
        , ( 7, '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 ) -- must be overriden by fork 2
        , ( 8, '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 ) -- must be overriden by fork 2
        , ( 9, '\xBADD9001', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 ) -- must be overriden by fork 2
        , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
        , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
        , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
        , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
        , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
        , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
        ;

    INSERT INTO hive.operations
    VALUES
           ( hive.operation_id(1, 1, 0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hive.operation )
         , ( hive.operation_id(2, 1, 0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hive.operation )
         , ( hive.operation_id(3, 1, 0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb :: hive.operation )
         , ( hive.operation_id(4, 1, 0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hive.operation )
         , ( hive.operation_id(5, 1, 0), 0, 0, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hive.operation )
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

    INSERT INTO hive.accounts
    VALUES
           ( 100, 'alice1', 1 )
         , ( 200, 'alice2', 2 )
         , ( 300, 'alice3', 3 )
         , ( 400, 'alice4', 4 )
    ;

    INSERT INTO hive.accounts_reversible
    VALUES
           ( 400, 'alice41', 4, 1 )
         , ( 500, 'alice51', 5, 1 )
         , ( 600, 'alice61', 6, 1 )
         , ( 700, 'alice71', 7, 1 ) -- must be overriden by fork 2
         , ( 800, 'bob71', 7, 1 )   -- must be overriden by fork 2
         , ( 900, 'alice81', 8, 1 ) -- must be overriden by fork 2
         , ( 900, 'alice91', 9, 2 ) -- must be overriden by fork 2
         , ( 700, 'alice72', 7, 2 )
         , ( 800, 'bob72', 7, 2 )
         , ( 1000, 'alice92', 9, 2 )
         , ( 900, 'alice83', 8, 3 )
         , ( 1000, 'alice93', 9, 3 )
         , ( 1100, 'alice103', 10, 3 )
    ;

    INSERT INTO hive.account_operations(account_id, account_op_seq_no, operation_id)
    VALUES
           ( 100, 1, hive.operation_id(1, 1, 0))
         , ( 100, 2, hive.operation_id(2, 1, 0))
         , ( 200, 1, hive.operation_id(2, 1, 0))
         , ( 300, 1, hive.operation_id(3, 1, 0))
         , ( 400, 1, hive.operation_id(4, 1, 0))
    ;

    INSERT INTO hive.account_operations_reversible
    VALUES
           ( 400, 1, hive.operation_id(4,1,0), 1 )
         , ( 500, 1, hive.operation_id(5,1,0), 1 )
         , ( 600, 1, hive.operation_id(6,1,0), 1 )
         , ( 700, 1, hive.operation_id(7,1,0), 1 ) -- must be overriden by fork 2
         , ( 800, 1, hive.operation_id(7,1,1), 1 ) -- must be overriden by fork 2
         , ( 900, 1, hive.operation_id(7,1,2), 1 ) -- must be overriden by fork 2
         , ( 700, 2, hive.operation_id(7,1,0), 2 )
         , ( 800, 2, hive.operation_id(7,1,1), 2 ) -- will be abandoned since fork 3 doesn not have this account operation
         , ( 900, 2, hive.operation_id(8,1,0), 2 )
         , ( 900, 3, hive.operation_id(7,1,0), 2 )
         , ( 1000, 2, hive.operation_id(9,1,0), 2 )
         , ( 900, 3, hive.operation_id(9,1,0), 3 )
         , ( 100, 3, hive.operation_id(10,1,0), 3 )
         , ( 1100, 3, hive.operation_id(10,1,0), 3 )
    ;

    UPDATE hive.contexts SET fork_id = 2, irreversible_block = 4, current_block_num = 8;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='account_operations_view' ), 'No context accounts operations view';

    ASSERT NOT EXISTS (
        SELECT * FROM a.account_operations_view
        EXCEPT SELECT * FROM ( VALUES
               ( 1, 100, 1, hive.operation_id(1, 1, 0), 1 )
             , ( 2, 100, 2, hive.operation_id(2, 1, 0), 1 )
             , ( 2, 200, 1, hive.operation_id(2, 1, 0), 1 )
             , ( 3, 300, 1, hive.operation_id(3, 1, 0), 1 )
             , ( 4, 400, 1, hive.operation_id(4, 1, 0), 1 )
        ) as pattern
    ) , 'Unexpected rows in the view';

    ASSERT ( SELECT COUNT(*) FROM a.account_operations_view ) = 5, 'Not all rows are visible';

END
$BODY$
;




