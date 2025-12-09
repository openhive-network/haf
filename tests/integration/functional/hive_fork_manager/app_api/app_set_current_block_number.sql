-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM test.create_blocks(1, 2);

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
    ;

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

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_set_current_block_num( ARRAY[ 'context_a', 'context_b', 'context_c' ], 10 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT hc.current_block_num FROM hafd.contexts hc WHERE hc.name = 'context_a' ) = 10, 'current_block_num is not 10 (a)';
    ASSERT ( SELECT hc.current_block_num FROM hafd.contexts hc WHERE hc.name = 'context_b' ) = 10, 'current_block_num is not 10 (b)';
    ASSERT ( SELECT hc.current_block_num FROM hafd.contexts hc WHERE hc.name = 'context_c' ) = 10, 'current_block_num is not 10 (c)';
END;
$BODY$
;


