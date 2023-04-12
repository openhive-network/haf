DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );

    INSERT INTO hive.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
         , (7, 'bob', 1)
    ;

    INSERT INTO hive.transactions
    VALUES
           ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( 3, 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hive.transactions_multisig
    VALUES
           ( '\xDEED10', '\xBAAD10' )
         , ( '\xDEED20', '\xBAAD20' )
         , ( '\xDEED30', '\xBAAD30' )
         , ( '\xDEED40', '\xBAAD40' )
    ;

    INSERT INTO hive.blocks_reversible
    VALUES
           ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:37-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 10, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:41-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
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
     , ( '\xDEED11', '\xBEEF7140',  1 ) --must be abandon because of fork 2
     , ( '\xDEED70', '\xBEEF72',  2 )
     , ( '\xDEED70', '\xBEEF73',  2 )
     , ( '\xDEED80', '\xBEEF82',  2 )
     , ( '\xDEED90', '\xBEEF92',  2 )
     , ( '\xDEED88', '\xBEEF83',  3 )
     , ( '\xDEED99', '\xBEEF93',  3 )
     , ( '\xDEED1102', '\xBEEF13',  3 )
    ;

    UPDATE hive.contexts SET fork_id = 2, irreversible_block = 4, current_block_num = 9;
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_transactions_multisig_view' ), 'No context transactions multisig view';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.context_transactions_multisig_view
        EXCEPT SELECT * FROM ( VALUES
               ( '\xDEED10'::bytea, '\xBAAD10'::bytea )
             , ( '\xDEED20'::bytea, '\xBAAD20'::bytea )
             , ( '\xDEED30'::bytea, '\xBAAD30'::bytea )
             , ( '\xDEED40'::bytea, '\xBAAD40'::bytea )
         ) as pattern
    ) , 'Unexpected rows in the view';

    ASSERT NOT EXISTS (
        SELECT * FROM ( VALUES
               ( '\xDEED10'::bytea, '\xBAAD10'::bytea )
             , ( '\xDEED20'::bytea, '\xBAAD20'::bytea )
             , ( '\xDEED30'::bytea, '\xBAAD30'::bytea )
             , ( '\xDEED40'::bytea, '\xBAAD40'::bytea )
         ) as pattern
        EXCEPT SELECT * FROM hive.context_transactions_multisig_view
    ) , 'Unexpected rows in the view 2';
END;
$BODY$
;




