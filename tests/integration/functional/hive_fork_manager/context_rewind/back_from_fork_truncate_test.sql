DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE SCHEMA B;
    PERFORM hive.context_create( 'context' );
    CREATE TABLE B.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );
    PERFORM hive.context_next_block( 'context' );
    INSERT INTO B.table1( id, smth ) VALUES( 123, 'blabla' );
    TRUNCATE hive.shadow_b_table1; --to do not revert inserts
    PERFORM hive.context_next_block( 'context' );
    TRUNCATE B.table1;
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
    ASSERT ( SELECT COUNT(*) FROM B.table1 WHERE id=123 ) = 1, 'Deleted row was not reinserted';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_b_table1 ) = 0, 'Shadow table is not empty';
END
$BODY$
;




