
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
CREATE TABLE table1( id INT ) INHERITS( a.context );

INSERT INTO hafd.fork( id, block_num, time_of_fork)
VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
       ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

INSERT INTO hafd.blocks
VALUES
       ( hafd.make_block_id(1, 0), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(2, 0), '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(3, 0), '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(4, 0), '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(5, 0), '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
;

INSERT INTO hafd.blocks
VALUES
       ( hafd.make_block_id(4, 1), '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(5, 1), '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(6, 1), '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(7, 1), '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 ) -- must be overriden by fork 2
     , ( hafd.make_block_id(8, 1), '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 ) -- must be overriden by fork 2
     , ( hafd.make_block_id(9, 1), '\xBADD9001', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 ) -- must be overriden by fork 2
     , ( hafd.make_block_id(7, 2), '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(8, 2), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(9, 2), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(8, 3), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(9, 3), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(10, 3), '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
;

INSERT INTO hafd.accounts
VALUES
       ( 100, 'alice1', hafd.make_block_id(1, 0) )
     , ( 200, 'alice2', hafd.make_block_id(2, 0) )
     , ( 300, 'alice3', hafd.make_block_id(3, 0) )
     , ( 400, 'alice4', hafd.make_block_id(4, 0) )
;

INSERT INTO hafd.accounts
VALUES
       ( 400, 'alice41', hafd.make_block_id(4, 1) )
     , ( 500, 'alice51', hafd.make_block_id(5, 1) )
     , ( 600, 'alice61', hafd.make_block_id(6, 1) )
     , ( 700, 'alice71', hafd.make_block_id(7, 1) ) -- must be overriden by fork 2
     , ( 800, 'bob71', hafd.make_block_id(7, 1) )   -- must be overriden by fork 2
     , ( 900, 'alice81', hafd.make_block_id(8, 1) ) -- must be overriden by fork 2
     , ( 900, 'alice91', hafd.make_block_id(9, 2) ) -- must be overriden by fork 2
     , ( 700, 'alice72', hafd.make_block_id(7, 2) )
     , ( 800, 'bob72', hafd.make_block_id(7, 2) )
     , ( 1000, 'alice92', hafd.make_block_id(9, 2) )
     , ( 900, 'alice83', hafd.make_block_id(8, 3) )
     , ( 1000, 'alice93', hafd.make_block_id(9, 3) )
     , ( 1100, 'alice103', hafd.make_block_id(10, 3) )
;

UPDATE hafd.contexts SET fork_id = 2, irreversible_block = 4, current_block_num = 8;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_context_detach( 'context' );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='accounts_view' ), 'No context accounts view';

    ASSERT NOT EXISTS (
        SELECT * FROM a.accounts_view
        EXCEPT SELECT * FROM ( VALUES
                   ( 100, 'alice1' )
                 , ( 200, 'alice2')
                 , ( 300, 'alice3' )
                 , ( 400, 'alice4' )
                 ) as pattern
    ) , 'Unexpected rows in the view';

    ASSERT ( SELECT COUNT(*) FROM a.accounts_view ) = 4, 'Not all rows are visible';

END
$BODY$
;




