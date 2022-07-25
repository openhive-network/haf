DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES (0, 'OP 0', FALSE )
        , ( 1, 'OP 1', FALSE )
        , ( 2, 'OP 2', FALSE )
        , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    INSERT INTO hive.transactions
    VALUES
           ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( 3, 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
         , ( 5, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hive.operations
    VALUES
          ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('ZERO OPERATION')::hive.system_warning_operation )
        , ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('ONE OPERATION')::hive.system_warning_operation )
        , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('TWO OPERATION')::hive.system_warning_operation )
        , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('THREE OPERATION')::hive.system_warning_operation )
        , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('FIVE OPERATION')::hive.system_warning_operation )
    ;

    INSERT INTO hive.blocks_reversible
    VALUES
           ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1 )
         , ( 5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1 )
         , ( 7, '\xBADD71', '\xCAFE71', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1 )
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 2 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 3 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 3 )
         , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 3 )
    ;

    INSERT INTO hive.transactions_reversible
    VALUES
       ( 6, 0::SMALLINT, '\xDEED60', 101, 100, '2016-06-22 19:10:26-07'::timestamp, '\xBEEF',  1 )
     , ( 7, 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF',  2 )
     , ( 8, 0::SMALLINT, '\xDEED80', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF',  2 )
     , ( 9, 0::SMALLINT, '\xDEED90', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF',  2 )
     , ( 8, 0::SMALLINT, '\xDEED88', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF',  3 )
     , ( 9, 0::SMALLINT, '\xDEED99', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF',  3 )
     , ( 10, 0::SMALLINT, '\xDEED11', 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF', 3 )
    ;

    INSERT INTO hive.operations_reversible
    VALUES
           ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('THREE OPERATION')::hive.system_warning_operation, 1 )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('FIVE OPERATION')::hive.system_warning_operation, 1 )
         , ( 6, 6, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SIX OPERATION')::hive.system_warning_operation, 1 )
         , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN0 OPERATION')::hive.system_warning_operation, 1 ) -- must be abandon because of fork2
         , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN01 OPERATION')::hive.system_warning_operation, 1 ) -- must be abandon because of fork2
         , ( 9, 7, 0, 2, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN02 OPERATION')::hive.system_warning_operation, 1 ) -- must be abandon because of fork2
         , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN2 OPERATION')::hive.system_warning_operation, 2 )
         , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN21 OPERATION')::hive.system_warning_operation, 2 )
         , ( 9, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('EAIGHT2 OPERATION')::hive.system_warning_operation, 2 )
         , ( 10, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('NINE2 OPERATION')::hive.system_warning_operation, 2 )
         , ( 9, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('EIGHT3 OPERATION')::hive.system_warning_operation, 3 )
         , ( 10, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('NINE3 OPERATION')::hive.system_warning_operation, 3 )
         , ( 11, 10, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('TEN OPERATION')::hive.system_warning_operation, 3 )
    ;

    UPDATE hive.irreversible_data SET consistent_block = 5;
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
    --NOTHING TODO HERE
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
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='operations_view' ), 'No transactions multisig view';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.operations_view
        EXCEPT SELECT * FROM ( VALUES
              ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('ZERO OPERATION')::hive.system_warning_operation :: hive.hive_operation )
            , ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('ONE OPERATION')::hive.system_warning_operation :: hive.hive_operation )
            , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('TWO OPERATION')::hive.system_warning_operation :: hive.hive_operation )
            , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('THREE OPERATION')::hive.system_warning_operation :: hive.hive_operation )
            , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('FIVE OPERATION')::hive.system_warning_operation :: hive.hive_operation )
            , ( 6, 6, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SIX OPERATION')::hive.system_warning_operation :: hive.hive_operation )
            , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN2 OPERATION')::hive.system_warning_operation :: hive.hive_operation )
            , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('SEVEN21 OPERATION')::hive.system_warning_operation :: hive.hive_operation )
            , ( 9, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('EIGHT3 OPERATION')::hive.system_warning_operation :: hive.hive_operation )
            , ( 10, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('NINE3 OPERATION')::hive.system_warning_operation :: hive.hive_operation )
            , ( 11, 10, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ROW('TEN OPERATION')::hive.system_warning_operation :: hive.hive_operation )
        ) as pattern
    ) , 'Unexpected rows in the view';

    ASSERT ( SELECT COUNT(*) FROM hive.operations_view ) = 11, 'Wrong number of operations';
END;
$BODY$
;




