DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync(2);

    PERFORM hive.app_create_context( 'context_a' );
    PERFORM hive.app_create_context( 'context_b' );
    PERFORM hive.app_create_context( 'context_c' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context_a );
    CREATE SCHEMA B;
    CREATE TABLE B.table1(id  INTEGER ) INHERITS( hive.context_b );
    CREATE SCHEMA C;
    CREATE TABLE C.table1(id  INTEGER ) INHERITS( hive.context_c );
    PERFORM hive.app_context_detach( ARRAY[ 'context_a', 'context_b', 'context_c' ] );
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
    BEGIN
        PERFORM hive.app_context_attach( ARRAY [ 'context_a', 'context_b', 'context_c' ], 5 );
        ASSERT FALSE, 'Cannot raise expected exception when block is greater than top of irreversible';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;




