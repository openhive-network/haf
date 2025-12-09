-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'context_a', 'a' );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context_a );

    CREATE SCHEMA B;
    PERFORM hive.app_create_context( 'context_b', 'b' );
    CREATE TABLE B.table1(id  INTEGER ) INHERITS( b.context_b );

    CREATE SCHEMA C;
    PERFORM hive.app_create_context( 'context_c','c' );
    CREATE TABLE C.table1(id  INTEGER ) INHERITS( c.context_c );

    -- Create blocks 1-5
    PERFORM test.create_blocks(1, 5);

    -- Create initminer account
    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1);

    PERFORM hive.set_irreversible( 5 );

    PERFORM hive.app_next_block( ARRAY[ 'context_a', 'context_b', 'context_c' ] );
    PERFORM hive.app_next_block( ARRAY[ 'context_a', 'context_b', 'context_c' ] );
    PERFORM hive.app_next_block( ARRAY[ 'context_a', 'context_b', 'context_c' ] );

    INSERT INTO  A.table1( id ) VALUES ( 66 ),( 67);
    INSERT INTO  A.table1( id ) VALUES ( 300 ),( 301);

    INSERT INTO  B.table1( id ) VALUES ( 66 ),( 67);
    INSERT INTO  B.table1( id ) VALUES ( 300 ),( 301);

    INSERT INTO  C.table1( id ) VALUES ( 66 ),( 67);
    INSERT INTO  C.table1( id ) VALUES ( 300 ),( 301);

    ASSERT ( SELECT count(*) FROM hafd.shadow_a_table1 ) = 4, 'shadow table has to be filled a';
    ASSERT ( SELECT count(*) FROM hafd.shadow_b_table1 ) = 4, 'shadow table has to be filled b';
    ASSERT ( SELECT count(*) FROM hafd.shadow_c_table1 ) = 4, 'shadow table has to be filled c';

    PERFORM hive.app_context_detach( ARRAY[ 'context_a', 'context_b', 'context_c' ] );
END;
$BODY$
;




