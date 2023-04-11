DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 3, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 4, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 5, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 6, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync( 1 );
    PERFORM hive.end_massive_sync( 2 );
    PERFORM hive.end_massive_sync( 3 );
    PERFORM hive.end_massive_sync( 4 );
    PERFORM hive.end_massive_sync( 5 );
    PERFORM hive.end_massive_sync( 6 );

    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- NOTHING TODO HERE
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
__blocks hive.blocks_range;
BEGIN
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- MASSIVE_SYNC(1)
    ASSERT __blocks IS NOT NULL, 'Null returned for MASSIVE_SYNC_1';
    RAISE NOTICE 'Received blocks=%', __blocks;
    ASSERT __blocks.first_block = 1, 'Incorrect first block 1';
    ASSERT __blocks.last_block = 6, 'Incorrect last range 6';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- MASSIVE_SYNC(2)
    ASSERT __blocks IS NOT NULL, 'Null returned for MASSIVE_SYNC_2';
    RAISE NOTICE 'Received blocks=%', __blocks;
    ASSERT __blocks.first_block = 2, 'Incorrect first block 2';
    ASSERT __blocks.last_block = 6, 'Incorrect last range 6';
END
$BODY$
;




