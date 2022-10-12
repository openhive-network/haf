DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );

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
        ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w' )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w' )
        , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w' )
        , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w' )
        , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w' )
    ;

    INSERT INTO hive.blocks_reversible
    VALUES
        ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1 )
        , ( 5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1 )
        , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1 )
        , ( 7, '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1 ) -- must be overriden by fork 2
        , ( 8, '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1 ) -- must be overriden by fork 2
        , ( 9, '\xBADD9001', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1 ) -- must be overriden by fork 2
        , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 2 )
        , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 2 )
        , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 2 )
        , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 3 )
        , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 3 )
        , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 3 )
        ;

    INSERT INTO hive.operations
    VALUES
           ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'ZERO OPERATION' )
         , ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'ONE OPERATION' )
         , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'TWO OPERATION' )
         , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'THREE OPERATION' )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'FIVE OPERATION' )
    ;

    INSERT INTO hive.operations_reversible
    VALUES
           ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'THREE OPERATION', 1 )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'FIVEFIVE OPERATION', 1 )
         , ( 6, 6, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'SIX OPERATION', 1 )
         , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'SEVEN0 OPERATION', 1 ) -- must be abandon because of fork2
         , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, 'SEVEN01 OPERATION', 1 ) -- must be abandon because of fork2
         , ( 9, 7, 0, 2, 1, '2016-06-22 19:10:21-07'::timestamp, 'SEVEN02 OPERATION', 1 ) -- must be abandon because of fork2
         , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'SEVEN2 OPERATION', 2 )
         , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, 'SEVEN21 OPERATION', 2 )
         , ( 9, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'EAIGHT2 OPERATION', 2 )
         , ( 10, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'NINE2 OPERATION', 2 )
         , ( 8, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'EIGHT3 OPERATION', 3 )
         , ( 9, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'NINE3 OPERATION', 3 )
         , ( 10, 10, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'TEN OPERATION', 3 )
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

    INSERT INTO hive.account_operations(block_num, account_id, account_op_seq_no, operation_id, op_type_id)
    VALUES
           ( 1, 100, 1, 1, 1 )
         , ( 2, 100, 2, 2, 1 )
         , ( 2, 200, 1, 2, 1 )
         , ( 3, 300, 1, 3, 1 )
         , ( 4, 400, 1, 4, 1 )
    ;

    INSERT INTO hive.account_operations_reversible
    VALUES
           ( 4, 400, 1, 4, 1, 1 )
         , ( 5, 500, 1, 5, 1, 1 )
         , ( 6, 600, 1, 6, 1, 1 )
         , ( 7, 700, 1, 7, 1, 1 ) -- must be overriden by fork 2
         , ( 7, 800, 1, 7, 1, 1 ) -- must be overriden by fork 2
         , ( 7, 900, 1, 9, 1, 1 ) -- must be overriden by fork 2
         , ( 7, 700, 2, 7, 1, 2 )
         , ( 7, 800, 2, 8, 1, 2 )
         , ( 8, 900, 2, 9, 1, 2 )
         , ( 7, 900, 3, 8, 1, 2 )
         , ( 9, 1000, 2, 10, 1, 2 )
         , ( 9, 900, 3, 9, 1, 3 )
         , ( 10, 1000, 3, 10, 1, 3 )
         , ( 10, 1100, 3, 10, 1, 3 )
    ;

    UPDATE hive.contexts SET fork_id = 2, irreversible_block = 4, current_block_num = 8;
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
    PERFORM hive.app_context_detach( 'context' );
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
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_account_operations_view' ), 'No context accounts operations view';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.context_account_operations_view
        EXCEPT SELECT * FROM ( VALUES
               ( 1, 100, 1, 1, 1 )
             , ( 2, 100, 2, 2, 1 )
             , ( 2, 200, 1, 2, 1 )
             , ( 3, 300, 1, 3, 1 )
             , ( 4, 400, 1, 4, 1 )
        ) as pattern
    ) , 'Unexpected rows in the view';

    ASSERT ( SELECT COUNT(*) FROM hive.context_account_operations_view ) = 5, 'Not all rows are visible';

END
$BODY$
;




