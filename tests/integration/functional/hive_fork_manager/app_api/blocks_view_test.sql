DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
    CREATE TABLE table1( id INT ) INHERITS( hive.context );

    INSERT INTO hive.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hive.blocks
    VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp )
        , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp )
        , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp )
        , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp )
    ;

    INSERT INTO hive.blocks_reversible
    VALUES
          ( 4, '\xBADD40', '\xCAFE42', '2016-06-22 19:10:24-07'::timestamp, 1 )
        , ( 5, '\xBADD50', '\xCAFE52', '2016-06-22 19:10:25-07'::timestamp, 1 )
        , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 1 )
        , ( 7, '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 1 ) -- must be overriden by fork 2
        , ( 8, '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 1 ) -- must be overriden by fork 2
        , ( 9, '\xBADD9001', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 1 ) -- must be overriden by fork 2
        , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 2 )
        , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 2 )
        , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 2 )
        , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 3 )
        , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 3 )
        , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 3 )
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
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='blocks_view' ), 'No context blocks view';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.blocks_view
        EXCEPT SELECT * FROM ( VALUES
                   (1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp)
                 , (2, '\xBADD20'::bytea, '\xCAFE20'::bytea, '2016-06-22 19:10:22-07'::timestamp)
                 , (3, '\xBADD30'::bytea, '\xCAFE30'::bytea, '2016-06-22 19:10:23-07'::timestamp)
                 , (4, '\xBADD40'::bytea, '\xCAFE40'::bytea, '2016-06-22 19:10:24-07'::timestamp)
                 , (5, '\xBADD50'::bytea, '\xCAFE50'::bytea, '2016-06-22 19:10:25-07'::timestamp )
                 , (6, '\xBADD60'::bytea, '\xCAFE60'::bytea, '2016-06-22 19:10:26-07'::timestamp)
                 , (7, '\xBADD70'::bytea, '\xCAFE70'::bytea, '2016-06-22 19:10:27-07'::timestamp)
                 , (8, '\xBADD80'::bytea, '\xCAFE80'::bytea, '2016-06-22 19:10:30-07'::timestamp )
                 , (9, '\xBADD90'::bytea, '\xCAFE90'::bytea, '2016-06-22 19:10:31-07'::timestamp )
                 , (10, '\xBADD1A'::bytea, '\xCAFE1A'::bytea, '2016-06-22 19:10:32-07'::timestamp )
                 ) as pattern
    ) , 'Unexpected rows in the view';

    ASSERT ( SELECT COUNT(*) FROM hive.blocks_view ) = 10, 'Wrong numbe rof rows';

END
$BODY$
;




