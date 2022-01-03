DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context' );
    CREATE TABLE a.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );
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
    PERFORM hive.context_next_block( 'context' );
    INSERT INTO A.table1( id, smth ) VALUES( 123, 'blabla' );
    PERFORM hive.context_next_block( 'context' );
    UPDATE A.table1 SET id=321;
    PERFORM hive.context_next_block( 'context' );
    DELETE FROM A.table1 WHERE id=321;
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
    ASSERT EXISTS ( SELECT FROM hive.shadow_a_table1 hs WHERE hs.id = 123 AND hs.hive_rowid = 1 AND hs.smth = 'blabla' AND hs.hive_block_num = 1 AND hs.hive_operation_type = 'INSERT' ), 'Lack of insert operation';
    ASSERT EXISTS ( SELECT FROM hive.shadow_a_table1 hs WHERE hs.id = 123 AND hs.hive_rowid = 1 AND hs.smth = 'blabla' AND hs.hive_block_num = 2 AND hs.hive_operation_type = 'UPDATE' ), 'Lack of update operation';
    ASSERT EXISTS ( SELECT FROM hive.shadow_a_table1 hs WHERE hs.id = 321 AND hs.hive_rowid = 1 AND hs.smth = 'blabla' AND hs.hive_block_num = 3 AND hs.hive_operation_type = 'DELETE' ), 'Lack of delete';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 ) = 3;
END
$BODY$
;




