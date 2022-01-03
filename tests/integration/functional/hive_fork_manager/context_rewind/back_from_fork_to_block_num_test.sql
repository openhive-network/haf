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
    PERFORM hive.context_next_block( 'context' ); -- block: 1
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla' );
    PERFORM hive.context_next_block( 'context' ); -- block: 2
    UPDATE table1 SET id=321;
    PERFORM hive.context_next_block( 'context' ); -- block: 3
    UPDATE table1 SET id=231;
    PERFORM hive.context_next_block( 'context' ); -- block: 4
    UPDATE table1 SET id=132;
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
    PERFORM hive.context_back_from_fork( 'context' , 2 );
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
    ASSERT ( SELECT COUNT(*) FROM table1 WHERE id=321 ) = 1, 'Updated row was not reverted or reverted to wrong number';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 2, 'Unexpected number of rows in the shadow table';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 WHERE hive_block_num = 1 ) = 1, 'No expected row (0) in the shadow table';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 WHERE hive_block_num = 2 ) = 1, 'No expected row (1) in the shadow table';
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name= 'context' ) = 2, 'Wrong current_block_num';
END
$BODY$
;




