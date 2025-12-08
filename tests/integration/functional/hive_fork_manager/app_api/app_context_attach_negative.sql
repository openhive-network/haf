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
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );
    PERFORM hive.app_context_detach( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_set_current_block_num( 'context', 5 );
    BEGIN
        CALL hive.appproc_context_attach( 'context' );
        ASSERT FALSE, 'Cannot raise expected exception when block is greater than top of irreversible';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;




