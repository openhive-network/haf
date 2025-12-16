-- Load test utilities
\ir ../test_tools.sql


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

    -- Create blocks 1-5 (irreversible, fork_id=0)
    PERFORM test.create_blocks(1, 5);

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
    ;

    -- Reversible blocks with fork_id > 0 (unified table)
    INSERT INTO hafd.blocks
    VALUES
          ( hafd.make_block_id(4, 1), '\xBADD40', '\xCAFE42', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(5, 1), '\xBADD50', '\xCAFE52', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(6, 1), '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(7, 1), '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(8, 1), '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(9, 1), '\xBADD9001', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(7, 2), '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(8, 2), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(9, 2), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(8, 3), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(9, 3), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(10, 3), '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(5, 0);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT (SELECT COUNT(1) FROM hive.get_block_range( 1, 3 )) = 3, 'Incorrect block range size';
    ASSERT (SELECT COUNT(1) FROM hive.get_block_range( 1, 3 ) WHERE block_id='\xBADD10'::bytea) = 1, 'Incorrect first block';
    ASSERT (SELECT COUNT(1) FROM hive.get_block_range( 1, 3 ) WHERE block_id='\xBADD20'::bytea) = 1, 'Incorrect second block';
    ASSERT (SELECT COUNT(1) FROM hive.get_block_range( 1, 3 ) WHERE block_id='\xBADD30'::bytea) = 1, 'Incorrect third block';
END
$BODY$
;
