
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context' );
    CREATE TABLE A.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );
    PERFORM hive.context_next_block( 'context' );

    -- one row inserted then deleted
    INSERT INTO A.table1( id, smth ) VALUES( 123, 'blabla' );
    DELETE FROM A.table1 WHERE id = 123;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_back_from_fork( 'context' , -1 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM A.table1 ) = 0, 'Inserted row was not removed';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 ) = 0, 'Shadow table is not empty';
END
$BODY$
;





