
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE table1( id INT ) INHERITS( a.context );

    INSERT INTO hafd.operation_types
    VALUES ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hafd.blocks
    VALUES
        ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.blocks_reversible
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

    INSERT INTO hafd.operations
    VALUES
           ( hafd.operation_id(1, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(2, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(3, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(4, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(5, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hafd.operation )
    ;

    INSERT INTO hafd.operations_reversible(id, trx_in_block, op_pos, body_binary, fork_id)
    VALUES
           ( hafd.operation_id(4,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(5,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVEFIVE OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(6,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(7,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN0 OPERATION"}}' :: jsonb :: hafd.operation, 1 ) -- must be abandon because of fork2
         , ( hafd.operation_id(7,1,1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN01 OPERATION"}}' :: jsonb :: hafd.operation, 1 ) -- must be abandon because of fork2
         , ( hafd.operation_id(7,1,2), 0, 2, '{"type":"system_warning_operation","value":{"message":"SEVEN02 OPERATION"}}' :: jsonb :: hafd.operation, 1 ) -- must be abandon because of fork2
         , ( hafd.operation_id(7,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(7,1,1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(8,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EAIGHT2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(9,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(8,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hafd.operation, 3 )
         , ( hafd.operation_id(9,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hafd.operation, 3 )
         , ( hafd.operation_id(10,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hafd.operation, 3 )
    ;

    INSERT INTO hafd.accounts
    VALUES
           ( 100, 'alice1', 1 )
         , ( 200, 'alice2', 2 )
         , ( 300, 'alice3', 3 )
         , ( 400, 'alice4', 4 )
    ;

    INSERT INTO hafd.accounts_reversible
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

    INSERT INTO hafd.account_operations(account_id, account_op_seq_no, operation_id)
    VALUES
           ( 100, 1, hafd.operation_id(1, 1, 0) )
         , ( 100, 2, hafd.operation_id(2, 1, 0) )
         , ( 200, 1, hafd.operation_id(2, 1, 0) )
         , ( 300, 1, hafd.operation_id(3, 1, 0) )
         , ( 400, 1, hafd.operation_id(4, 1, 0) )
    ;

    INSERT INTO hafd.account_operations_reversible
    VALUES
           ( 400, 1, hafd.operation_id(4,1,0), 1 )
         , ( 500, 1, hafd.operation_id(5,1,0), 1 )
         , ( 600, 1, hafd.operation_id(6,1,0), 1 )
         , ( 700, 1, hafd.operation_id(7,1,0), 1 ) -- must be overriden by fork 2
         , ( 800, 1, hafd.operation_id(7,1,1), 1 ) -- must be overriden by fork 2
         , ( 900, 1, hafd.operation_id(7,1,2), 1 ) -- must be overriden by fork 2
         , ( 700, 2, hafd.operation_id(7,1,0), 2 )
         , ( 800, 2, hafd.operation_id(7,1,1), 2 ) -- will be abandoned since fork 3 doesn not have this account operation
         , ( 900, 2, hafd.operation_id(8,1,0), 2 )
         , ( 900, 3, hafd.operation_id(7,1,0), 2 )
         , ( 1000, 2, hafd.operation_id(9,1,0), 2 )
         , ( 900, 3, hafd.operation_id(9,1,0), 3 )
         , ( 100, 3, hafd.operation_id(10,1,0), 3 )
         , ( 1100, 3, hafd.operation_id(10,1,0), 3 )
    ;

    UPDATE hafd.contexts SET fork_id = 2, irreversible_block = 4, current_block_num = 8;
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
              ( 1, 100, 1, hafd.operation_id(1, 1, 0), 1 )
            , ( 2, 100, 2, hafd.operation_id(2, 1, 0), 1 )
            , ( 2, 200, 1, hafd.operation_id(2, 1, 0), 1 )
            , ( 3, 300, 1, hafd.operation_id(3, 1, 0), 1 )
            , ( 4, 400, 1, hafd.operation_id(4, 1, 0), 1 )
            , ( 5, 500, 1, hafd.operation_id(5, 1, 0), 1 )
            , ( 6, 600, 1, hafd.operation_id(6, 1, 0), 1 )
            , ( 7, 700, 2, hafd.operation_id(7, 1, 0), 1 )
            , ( 7, 800, 2, hafd.operation_id(7, 1, 1), 1 )
            , ( 8, 900, 2, hafd.operation_id(8, 1, 0), 1 )
            , ( 7, 900, 3, hafd.operation_id(7, 1, 0), 1 )
        ) as pattern
    ) , 'Unexpected rows in the view';

    ASSERT ( SELECT COUNT(*) FROM a.account_operations_view ) = 11, 'Not all rows are visible';

END
$BODY$
;




