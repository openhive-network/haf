
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 6, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
    ;

    CREATE SCHEMA A;
    CREATE SCHEMA B;
    CREATE SCHEMA C;

    PERFORM hive.app_create_context( 'context_a', 'a' );
    PERFORM hive.app_create_context( 'context_b', 'b' );
    PERFORM hive.app_create_context( 'context_c', 'c' );

    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context_a );

    CREATE TABLE B.table1(id  INTEGER ) INHERITS( b.context_b );

    CREATE TABLE C.table1(id  INTEGER ) INHERITS( c.context_c );

    PERFORM hive.app_context_detach( ARRAY[ 'context_a', 'context_b', 'context_c' ] );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_set_current_block_num( ARRAY[ 'context_a', 'context_b', 'context_c' ], 2 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT hive.app_get_current_block_num( ARRAY[ 'context_a', 'context_b', 'context_c' ] ) ) = 2, 'returned block_num is not 2';
END;
$BODY$
;




