
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive_data.operation_types
    VALUES (0, 'OP 0', FALSE )
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

    INSERT INTO hive_data.transactions
    VALUES
           ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( 3, 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
         , ( 5, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hive_data.operations
    VALUES
          ( hive.operation_id(1, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hive_data.operation )
        , ( hive.operation_id(2, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hive_data.operation )
        , ( hive.operation_id(3, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb :: hive_data.operation )
        , ( hive.operation_id(4, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hive_data.operation )
        , ( hive.operation_id(5, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hive_data.operation )
    ;

    INSERT INTO hive_data.blocks_reversible
    VALUES
           ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD71', '\xCAFE71', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
    ;

    INSERT INTO hive_data.transactions_reversible
    VALUES
       ( 6, 0::SMALLINT, '\xDEED60', 101, 100, '2016-06-22 19:10:26-07'::timestamp, '\xBEEF',  1 )
     , ( 7, 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF',  2 )
     , ( 8, 0::SMALLINT, '\xDEED80', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF',  2 )
     , ( 9, 0::SMALLINT, '\xDEED90', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF',  2 )
     , ( 8, 0::SMALLINT, '\xDEED88', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF',  3 )
     , ( 9, 0::SMALLINT, '\xDEED99', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF',  3 )
     , ( 10, 0::SMALLINT, '\xDEED11', 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF', 3 )
    ;

    INSERT INTO hive_data.operations_reversible(id, trx_in_block, op_pos, body_binary, fork_id)
    VALUES
           ( hive.operation_id(4, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hive_data.operation, 1 )
         , ( hive.operation_id(5, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hive_data.operation, 1 )
         , ( hive.operation_id(6, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb :: hive_data.operation, 1 )
         , ( hive.operation_id(7, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN0 OPERATION"}}' :: jsonb :: hive_data.operation, 1 ) -- must be abandon because of fork2
         , ( hive.operation_id(7, 1, 1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN01 OPERATION"}}' :: jsonb :: hive_data.operation, 1 ) -- must be abandon because of fork2
         , ( hive.operation_id(7, 1, 2), 0, 2, '{"type":"system_warning_operation","value":{"message":"SEVEN02 OPERATION"}}' :: jsonb :: hive_data.operation, 1 ) -- must be abandon because of fork2
         , ( hive.operation_id(7, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hive_data.operation, 2 )
         , ( hive.operation_id(7, 1, 1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hive_data.operation, 2 )
         , ( hive.operation_id(8, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EAIGHT2 OPERATION"}}' :: jsonb :: hive_data.operation, 2 )
         , ( hive.operation_id(9, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hive_data.operation, 2 )
         , ( hive.operation_id(8, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hive_data.operation, 3 )
         , ( hive.operation_id(9, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hive_data.operation, 3 )
         , ( hive.operation_id(10, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hive_data.operation, 3 )
    ;

    UPDATE hive_data.irreversible_data SET consistent_block = 5;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='operations_view' ), 'No operations view';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.operations_view
        EXCEPT SELECT * FROM ( VALUES
              ( hive.operation_id(1, 1, 0), 1, 0, 0, 1, '\x520e5a45524f204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb )
            , ( hive.operation_id(2, 1, 0), 2, 0, 0, 1, '\x520d4f4e45204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb )
            , ( hive.operation_id(3, 1, 0), 3, 0, 0, 1, '\x520d54574f204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb )
            , ( hive.operation_id(4, 1, 0), 4, 0, 0, 1, '\x520f5448524545204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb )
            , ( hive.operation_id(5, 1, 0), 5, 0, 0, 1, '\x520e46495645204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb )
            , ( hive.operation_id(6, 1, 0), 6, 0, 0, 1, '\x520d534958204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb )
            , ( hive.operation_id(7, 1, 0), 7, 0, 0, 1, '\x5210534556454e32204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb )
            , ( hive.operation_id(7, 1, 1), 7, 0, 1, 1, '\x5211534556454e3231204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb )
            , ( hive.operation_id(8, 1, 0), 8, 0, 0, 1, '\x5210454947485433204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb )
            , ( hive.operation_id(9, 1, 0), 9, 0, 0, 1, '\x520f4e494e4533204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb )
            , ( hive.operation_id(10, 1, 0), 10, 0, 0, 1,'\x520d54454e204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb )
        ) as pattern
    ) , 'Unexpected rows in the view';

    ASSERT ( SELECT COUNT(*) FROM hive.operations_view ) = 11, 'Wrong number of operations';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='irreversible_operations_view' ), 'No irreversible operations view';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.irreversible_operations_view
        EXCEPT SELECT * FROM ( VALUES
                                  ( hive.operation_id(1, 1, 0), 1, 0, 0, 1, '\x520e5a45524f204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb )
                                , ( hive.operation_id(2, 1, 0), 2, 0, 0, 1, '\x520d4f4e45204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb )
                                , ( hive.operation_id(3, 1, 0), 3, 0, 0, 1, '\x520d54574f204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb )
                                , ( hive.operation_id(4, 1, 0), 4, 0, 0, 1, '\x520f5448524545204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb )
                                , ( hive.operation_id(5, 1, 0), 5, 0, 0, 1, '\x520e46495645204f5045524154494f4e' :: hive_data.operation, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb )

                             ) as pattern
    ) , 'Unexpected rows in the irreversible view';

    ASSERT ( SELECT COUNT(*) FROM hive.irreversible_operations_view ) = 5, 'Wrong number of irreversible operations';
END;
$BODY$
;




