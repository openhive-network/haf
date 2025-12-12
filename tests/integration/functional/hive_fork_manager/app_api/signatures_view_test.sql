
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hafd.blocks
    VALUES
           ( hafd.make_block_id(1, 0), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5 , '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(2, 0), '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(3, 0), '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(4, 0), '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(5, 0), '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
    ;

    INSERT INTO hafd.transactions
    VALUES
           ( hafd.make_block_id(1, 0), 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(2, 0), 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(3, 0), 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(4, 0), 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(5, 0), 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.transactions_multisig
    VALUES
           ( hafd.make_block_id(1, 0), 0::SMALLINT, '\xBAAD10' )
         , ( hafd.make_block_id(2, 0), 0::SMALLINT, '\xBAAD20' )
         , ( hafd.make_block_id(3, 0), 0::SMALLINT, '\xBAAD30' )
         , ( hafd.make_block_id(4, 0), 0::SMALLINT, '\xBAAD40' )
         , ( hafd.make_block_id(5, 0), 0::SMALLINT, '\xBAAD50' )
    ;

    INSERT INTO hafd.blocks
    VALUES
           ( hafd.make_block_id(4, 1), '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(5, 1), '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(6, 1), '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(7, 1), '\xBADD70', '\xCAFE70', '2016-06-22 19:10:37-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(10, 1), '\xBADD11', '\xCAFE11', '2016-06-22 19:10:41-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(7, 2), '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(8, 2), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(9, 2), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(8, 3), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(9, 3), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(10, 3), '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.transactions
    VALUES
       ( hafd.make_block_id(4, 1), 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(5, 1), 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(6, 1), 0::SMALLINT, '\xDEED60', 101, 100, '2016-06-22 19:10:26-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(7, 1), 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:37-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(10, 1), 0::SMALLINT, '\xDEED11', 101, 100, '2016-06-22 19:10:41-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(7, 2), 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(8, 2), 0::SMALLINT, '\xDEED80', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(9, 2), 0::SMALLINT, '\xDEED90', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(8, 3), 0::SMALLINT, '\xDEED88', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(9, 3), 0::SMALLINT, '\xDEED99', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(10, 3), 0::SMALLINT, '\xDEED1102', 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.transactions_multisig
    VALUES
       ( hafd.make_block_id(4, 1), 0::SMALLINT, '\xBAAD40' )
     , ( hafd.make_block_id(5, 1), 0::SMALLINT, '\xBAAD50' )
     , ( hafd.make_block_id(6, 1), 0::SMALLINT, '\xBEEF61' )
     , ( hafd.make_block_id(7, 1), 0::SMALLINT, '\xBEEF7110' ) --must be abandon because of fork 2
     , ( hafd.make_block_id(7, 1), 0::SMALLINT, '\xBEEF7120' ) --must be abandon because of fork 2
     , ( hafd.make_block_id(7, 1), 0::SMALLINT, '\xBEEF7130' ) --must be abandon because of fork 2
     , ( hafd.make_block_id(10, 1), 0::SMALLINT, '\xBEEF7140' ) --must be abandon because of fork 2
     , ( hafd.make_block_id(7, 2), 0::SMALLINT, '\xBEEF72' )
     , ( hafd.make_block_id(7, 2), 0::SMALLINT, '\xBEEF73' )
     , ( hafd.make_block_id(8, 2), 0::SMALLINT, '\xBEEF82' )
     , ( hafd.make_block_id(9, 2), 0::SMALLINT, '\xBEEF92' )
     , ( hafd.make_block_id(8, 3), 0::SMALLINT, '\xBEEF83' )
     , ( hafd.make_block_id(9, 3), 0::SMALLINT, '\xBEEF93' )
     , ( hafd.make_block_id(10, 3), 0::SMALLINT, '\xBEEF13' )
    ;

    UPDATE hafd.hive_state SET consistent_block = 5;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='transactions_multisig_view' ), 'No transactions multisig view';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.transactions_multisig_view
        EXCEPT SELECT * FROM ( VALUES
              ( '\xDEED10'::bytea, '\xBAAD10'::bytea )
            , ( '\xDEED20'::bytea, '\xBAAD20'::bytea )
            , ( '\xDEED30'::bytea, '\xBAAD30'::bytea )
            , ( '\xDEED40'::bytea, '\xBAAD40'::bytea )
            , ( '\xDEED50'::bytea, '\xBAAD50'::bytea )
            , ( '\xDEED60'::bytea, '\xBEEF61'::bytea )
            , ( '\xDEED70'::bytea, '\xBEEF72'::bytea )
            , ( '\xDEED70'::bytea, '\xBEEF73'::bytea )
            , ( '\xDEED88'::bytea, '\xBEEF83'::bytea )
            , ( '\xDEED99'::bytea, '\xBEEF93'::bytea )
            , ( '\xDEED1102'::bytea, '\xBEEF13'::bytea )
         ) as pattern
    ) , 'Unexpected rows in the view';

    ASSERT ( SELECT COUNT(*) FROM hive.transactions_multisig_view ) = 11, 'Wrong number of rows';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='irreversible_transactions_multisig_view' ), 'No irreversible transactions multisig view';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.irreversible_transactions_multisig_view
        EXCEPT SELECT * FROM ( VALUES
                                  ( '\xDEED10'::bytea, '\xBAAD10'::bytea )
                                , ( '\xDEED20'::bytea, '\xBAAD20'::bytea )
                                , ( '\xDEED30'::bytea, '\xBAAD30'::bytea )
                                , ( '\xDEED40'::bytea, '\xBAAD40'::bytea )
                                , ( '\xDEED50'::bytea, '\xBAAD50'::bytea )
                             ) as pattern
    ) , 'Unexpected rows in the irreversible view';

    ASSERT ( SELECT COUNT(*) FROM hive.irreversible_transactions_multisig_view ) = 5, 'Wrong number of irreversible rows';
END;
$BODY$
;




