DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    CREATE TABLE table1( id INTEGER PRIMARY KEY, smth TEXT NOT NULL ) INHERITS( hive.context );
    CREATE TABLE table2(
          id INTEGER NOT NULL
        , smth TEXT NOT NULL
        , table1_id INTEGER NOT NULL
        , CONSTRAINT fk_table2_table1_id FOREIGN KEY( table1_id ) REFERENCES table1(id) DEFERRABLE
    ) INHERITS( hive.context );

    PERFORM hive.context_next_block( 'context' );

    -- one row inserted, ready to back from fork
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO table2( id, smth, table1_id ) VALUES( 223, 'blabla2', 123 );
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- because table1 will be first rewinded table2 will stay with incorrect FK for tabe1(id)
    PERFORM hive.context_back_from_fork( 'context' , -1 );
END
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM table1 ) = 0, 'Inserted row was not removed table1';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 0, 'Shadow table is not empty table1';

    ASSERT ( SELECT COUNT(*) FROM table2 ) = 0, 'Inserted row was not removed table2';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table2 ) = 0, 'Shadow table is not empty table2';
END
$BODY$
;





