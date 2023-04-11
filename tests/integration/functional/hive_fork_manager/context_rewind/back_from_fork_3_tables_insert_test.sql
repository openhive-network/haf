DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    CREATE SCHEMA B;
    PERFORM hive.context_create( 'context' );

    CREATE TABLE A.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );
    CREATE TABLE B.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );
    CREATE TABLE table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );

    PERFORM hive.context_next_block( 'context' );

    -- one row inserted, ready to back from fork
    INSERT INTO A.table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO B.table1( id, smth ) VALUES( 223, 'blabla2' );
    INSERT INTO table1( id, smth ) VALUES( 323, 'blabla3' );
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
    PERFORM hive.context_back_from_fork( 'context' , -1 );
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM A.table1 ) = 0, 'Inserted row was not removed table1';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 ) = 0, 'Shadow table is not empty table1';

    ASSERT ( SELECT COUNT(*) FROM B.table1 ) = 0, 'Inserted row was not removed table2';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_b_table1 ) = 0, 'Shadow table is not empty table2';

    ASSERT ( SELECT COUNT(*) FROM table1 ) = 0, 'Inserted row was not removed table3';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 0, 'Shadow table is not empty table3';
END
$BODY$
;





