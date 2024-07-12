CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE A.table1( id SERIAL PRIMARY KEY DEFERRABLE, smth INTEGER, name hive.ctext ) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ALTER TABLE a.table1 ADD COLUMN test_column INTEGER;
    PERFORM hive.context_next_block( 'context' );
    INSERT INTO a.table1( test_column ) VALUES( 10 );

    TRUNCATE hive.shadow_a_table1; --to do not revert already inserted rows
    INSERT INTO a.table1( smth, name ) VALUES( 1, 'abc' );
    UPDATE a.table1 SET test_column = 1 WHERE test_column= 10;

    PERFORM hive.context_back_from_fork( 'context' , -1 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS(
        SELECT * FROM information_schema.columns iss WHERE iss.table_name='table1' AND iss.column_name='test_column'
        )
        , 'Column was inserted'
    ;

    ASSERT ( SELECT COUNT(*) FROM a.table1 WHERE name ='abc' ) = 0, 'Back from fork did not revert insert operation';
    ASSERT ( SELECT COUNT(*) FROM a.table1 WHERE test_column = 10 ) = 1, 'Updated new column was not reverted';
END;
$BODY$
;




