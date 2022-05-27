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

    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 100 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 100 )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 100 )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 100 )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 100 )
    ;

    INSERT INTO hive.blocks_reversible
    VALUES
           ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 100, 1 )
         , ( 5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 100, 1 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 100, 1 )
         , ( 7, '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 100, 1 ) -- must be overriden by fork 2
         , ( 8, '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 100, 1 ) -- must be overriden by fork 2
         , ( 9, '\xBADD9001', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 100, 1 ) -- must be overriden by fork 2
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 100, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 100, 2 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 100, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 100, 3 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 100, 3 )
         , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 100, 3 )
    ;

    INSERT INTO hive.accounts
    VALUES
           ( 100, 'alice1', 1 )
         , ( 200, 'alice2', 2 )
         , ( 300, 'alice3', 3 )
         , ( 400, 'alice4', 4 )
         , ( 500, 'alice5', 5 )
    ;

    INSERT INTO hive.accounts_reversible
    VALUES
           ( 400, 'alice4', 4, 1 )
         , ( 500, 'alice5', 5, 1 )
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
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='accounts_view' ), 'No accounts view';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.accounts_view
        EXCEPT SELECT * FROM ( VALUES
              ( 1, 100, 'alice1' )
            , ( 2, 200, 'alice2' )
            , ( 3, 300, 'alice3' )
            , ( 4, 400, 'alice4' )
            , ( 5, 500, 'alice5' )
            , ( 6, 600, 'alice61' )
            , ( 7, 700, 'alice72' )
            , ( 7, 800, 'bob72' )
            , ( 8, 900, 'alice83' )
            , ( 9, 1000, 'alice93' )
            , ( 10, 1100, 'alice103' )
        ) as pattern
    ) , 'Unexpected rows in the view';

    ASSERT ( SELECT COUNT(*) FROM hive.accounts_view ) = 11, 'Wrong number of rows';
END
$BODY$
;




