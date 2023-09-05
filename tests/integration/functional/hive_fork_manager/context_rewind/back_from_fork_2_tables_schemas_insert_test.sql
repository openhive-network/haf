
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    CREATE SCHEMA A;
    CREATE SCHEMA B;

    CREATE TABLE A.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );
    CREATE TABLE B.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );


    PERFORM hive.context_next_block( 'context' );

    -- one row inserted, ready to back from fork
    INSERT INTO A.table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO B.table1( id, smth ) VALUES( 223, 'blabla2' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_back_from_fork( 'context', -1 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM A.table1 ) = 0, 'Inserted row was not removed a.table1';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 ) = 0, 'Shadow table is not empty table1';

    ASSERT ( SELECT COUNT(*) FROM B.table1 ) = 0, 'Inserted row was not removed b.table1';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_b_table1 ) = 0, 'Shadow table is not empty table2';
END
$BODY$
;





