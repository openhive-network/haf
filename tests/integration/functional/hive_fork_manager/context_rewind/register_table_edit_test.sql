DROP FUNCTION IF EXISTS alice_test_given;
CREATE FUNCTION alice_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    CREATE TABLE table1( id SERIAL PRIMARY KEY DEFERRABLE, smth INTEGER, name TEXT ) INHERITS( hive.context );
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_when;
CREATE FUNCTION alice_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    ALTER TABLE table1 ADD COLUMN test_column INTEGER;
    PERFORM hive.context_next_block( 'context' );
    INSERT INTO table1( test_column ) VALUES( 10 );

    TRUNCATE hive.shadow_public_table1; --to do not revert already inserted rows
    INSERT INTO table1( smth, name ) VALUES( 1, 'abc' );
    UPDATE table1 SET test_column = 1 WHERE test_column= 10;

    PERFORM hive.context_back_from_fork( 'context' , -1 );
END;
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
    ASSERT EXISTS(
        SELECT * FROM information_schema.columns iss WHERE iss.table_name='table1' AND iss.column_name='test_column'
        )
        , 'Column was inserted'
    ;

    ASSERT ( SELECT COUNT(*) FROM table1 WHERE name ='abc' ) = 0, 'Back from fork did not revert insert operation';
    ASSERT ( SELECT COUNT(*) FROM table1 WHERE test_column = 10 ) = 1, 'Updated new column was not reverted';
END;
$BODY$
;




