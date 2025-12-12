-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );

    -- Create blocks 1-5
    PERFORM test.create_blocks(1, 5);

    -- Create initminer account
    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0));

    PERFORM hive.set_irreversible( 5 );

    PERFORM hive.app_next_block( 'context' );
    PERFORM hive.app_next_block( 'context' );
    PERFORM hive.app_next_block( 'context' );

    INSERT INTO  A.table1( id ) VALUES ( 66 ),( 67);
    INSERT INTO  A.table1( id ) VALUES ( 300 ),( 301);

    ASSERT ( SELECT count(*) FROM hafd.shadow_a_table1 ) = 4, 'shadow table has to be filled';

    PERFORM hive.app_context_detach( 'context' );
END;
$BODY$
;




