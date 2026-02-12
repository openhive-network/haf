-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM test.create_blocks(1, 2);

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
         , (6, 'alice', hafd.make_block_id(1, 0))
    ;

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    BEGIN
        PERFORM hive.app_set_current_block_num( 'context' );
        ASSERT FALSE, 'No exception when context is attached';
        EXCEPTION WHEN OTHERS THEN
    END;

    PERFORM hive.app_context_detach( 'context' );

    BEGIN
        PERFORM hive.app_set_current_block_num( 'nonexistent_context', 2 );
        ASSERT FALSE, 'No exception when nonexistent_context';
        EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    return;
    ASSERT ( SELECT hive.app_get_current_block_num( 'context' ) ) IS NULL, 'NULL was not returned';
END;
$BODY$
;




