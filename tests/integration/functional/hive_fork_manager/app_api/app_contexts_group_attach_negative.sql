-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Create blocks 1-2
    PERFORM test.create_blocks(1, 2);

    -- Create initminer account
    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1);

    PERFORM hive.end_massive_sync(2);

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
    BEGIN
        CALL hive.appproc_context_attach( ARRAY [ 'context_a', 'context_b', 'context_c' ], 5 );
        ASSERT FALSE, 'Cannot raise expected exception when block is greater than top of irreversible';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;




