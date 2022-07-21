DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hive.operation_types
    VALUES ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 7, '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 8, '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w' )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (15, 'initminer', 1)
         , (16, 'alice', 1)
         , (17, 'bob', 1)
    ;

    INSERT INTO hive.blocks_reversible
    VALUES
           ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1 )
         , ( 5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1 )
         , ( 7, '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1 ) -- must be overriden by fork 2
         , ( 8, '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1 ) -- must be overriden by fork 2
         , ( 9, '\xBADD9001', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 1 ) -- must be overriden by fork 2
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 2 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 3 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 3 )
         , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 15, '\x4007', E'[]', '\x2157', 'STM65w', 3 )
    ;

    INSERT INTO hive.operations
    VALUES
           ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('ZERO OPERATION')::hive.system_warning_operation )
         , ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('ONE OPERATION')::hive.system_warning_operation )
         , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('TWO OPERATION')::hive.system_warning_operation )
         , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('THREE OPERATION')::hive.system_warning_operation )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('FIVE OPERATION')::hive.system_warning_operation )
         , ( 6, 6, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SIX OPERATION')::hive.system_warning_operation )
         , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN2 OPERATION')::hive.system_warning_operation )
         , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN21 OPERATION')::hive.system_warning_operation )
         , ( 9, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('EAIGHT2 OPERATION')::hive.system_warning_operation )
    ;

    INSERT INTO hive.operations_reversible
    VALUES
           ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('THREE OPERATION')::hive.system_warning_operation, 1 )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('FIVEFIVE OPERATION')::hive.system_warning_operation, 1 )
         , ( 6, 6, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SIX OPERATION')::hive.system_warning_operation, 1 )
         , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN0 OPERATION')::hive.system_warning_operation, 1 ) -- must be abandon because of fork2
         , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN01 OPERATION')::hive.system_warning_operation, 1 ) -- must be abandon because of fork2
         , ( 9, 7, 0, 2, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN02 OPERATION')::hive.system_warning_operation, 1 ) -- must be abandon because of fork2
         , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN2 OPERATION')::hive.system_warning_operation, 2 )
         , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN21 OPERATION')::hive.system_warning_operation, 2 )
         , ( 9, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('EAIGHT2 OPERATION')::hive.system_warning_operation, 2 )
         , ( 10, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('NINE2 OPERATION')::hive.system_warning_operation, 2 )
         , ( 8, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('EIGHT3 OPERATION')::hive.system_warning_operation, 3 )
         , ( 9, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('NINE3 OPERATION')::hive.system_warning_operation, 3 )
         , ( 10, 10, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('TEN OPERATION')::hive.system_warning_operation, 3 )
    ;

    INSERT INTO hive.accounts
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

    INSERT INTO hive.accounts_reversible
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

    INSERT INTO hive.account_operations(block_num, account_id, account_op_seq_no, operation_id, op_type_id)
    VALUES
           ( 1, 1, 1, 1, 1 )
         , ( 2, 1, 2, 2, 1 )
         , ( 2, 2, 1, 2, 1 )
         , ( 3, 3, 1, 3, 1 )
         , ( 4, 4, 1, 4, 1 )
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
         , ( 7, 8, 2, 8, 1, 2 )
         , ( 8, 9, 2, 9, 1, 2 )
         , ( 7, 9, 3, 8, 1, 2 )
         , ( 9, 10, 2, 10, 1, 2 )
         , ( 9, 9, 3, 9, 1, 3 )
         , ( 10, 10, 3, 10, 1, 3 )
         , ( 10,11, 3, 10, 1, 3 )
    ;
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.copy_account_operations_to_irreversible( 4, 8 );
END
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS (
        SELECT * FROM hive.account_operations
        EXCEPT SELECT * FROM ( VALUES
                   ( 1, 1, 1, 1, 1 )
                 , ( 2, 1, 2, 2, 1 )
                 , ( 2, 2, 1, 2, 1 )
                 , ( 3, 3, 1, 3, 1 )
                 , ( 4, 4, 1, 4, 1 )
                 , ( 5, 5, 1, 5, 1 )
                 , ( 6, 6, 1, 6, 1 )
                 , ( 7, 7, 2, 7, 1 )
                 , ( 7, 8, 2, 8, 1 )
                 , ( 7, 9, 3, 8, 1 )
                 ) as pattern
    ) , 'Unexpected rows in the account_operations1';

    ASSERT ( SELECT COUNT(*) FROM hive.account_operations ) = 10, 'Wrong number of rows';

END
$BODY$
;




