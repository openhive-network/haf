DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
DECLARE
    __account hive.accounts%ROWTYPE;
BEGIN
    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_create_context( 'context_b' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );

    CREATE SCHEMA B;
    CREATE TABLE B.table1(id  INTEGER ) INHERITS( hive.context_b );

    __account = ( 5, 'initminer', 1 );
    PERFORM hive.push_block(
         ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , ARRAY[ __account ]
        , NULL
        , NULL
    );


    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.push_block(
         ( 4, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.set_irreversible( 2 );
    PERFORM hive.app_next_block( ARRAY[ 'context_b', 'context' ] ); --block 1,2
    PERFORM hive.app_context_detach( ARRAY[ 'context_b', 'context' ] );
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
    -- reproduce issue #13: problem with switching to live synchronization
    PERFORM hive.set_irreversible( 4 );
    PERFORM hive.app_context_attach( ARRAY[ 'context_b', 'context' ], 2 );
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    SELECT * FROM hive.app_next_block( ARRAY[ 'context_b', 'context' ] ) INTO __blocks;
    RAISE NOTICE 'Blocks range %', __blocks;
    ASSERT __blocks IS NULL, 'Not NULL returned for NEW_IRREVERSIBLE(4)';

    SELECT * FROM hive.app_next_block( ARRAY[ 'context_b', 'context' ] ) INTO __blocks;
    ASSERT __blocks IS NOT NULL, 'Null returned';
    ASSERT __blocks.first_block = 3, 'Wrong first block';
    ASSERT __blocks.last_block = 4, 'Wrong first block';
END
$BODY$
;




