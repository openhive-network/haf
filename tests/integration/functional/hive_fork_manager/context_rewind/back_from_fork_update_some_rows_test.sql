DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    CREATE TABLE table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );

    PERFORM hive.context_next_block( 'context' );
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO table1( id, smth ) VALUES( 223, 'blabla2' );
    INSERT INTO table1( id, smth ) VALUES( 323, 'blabla3' );
    PERFORM hive.context_next_block( 'context' );

    TRUNCATE hive.shadow_public_table1; --to do not revert inserts
    UPDATE table1 SET smth='a1' WHERE id=123;
    UPDATE table1 SET smth='a2' WHERE id=223;
    UPDATE table1 SET smth='a3' WHERE id=323;
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
    ASSERT ( SELECT COUNT(*) FROM table1 WHERE id=123 AND smth='blabla1' ) = 1, 'Updated row was not reverted';
    ASSERT ( SELECT COUNT(*) FROM table1 WHERE id=223 AND smth='blabla2' ) = 1, 'Updated row was not reverted';
    ASSERT ( SELECT COUNT(*) FROM table1 WHERE id=323 AND smth='blabla3' ) = 1, 'Updated row was not reverted';

    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 0, 'Shadow table is not empty';
END
$BODY$
;




