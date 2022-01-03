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

    CREATE TABLE A.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );
    CREATE TABLE A.table2( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );
    CREATE TABLE table3( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );

    PERFORM hive.context_next_block( 'context' );
    PERFORM hive.context_next_block( 'context' );
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
    INSERT INTO A.table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO A.table2( id, smth ) VALUES( 223, 'blabla2' );
    INSERT INTO table3( id, smth ) VALUES( 323, 'blabla3' );
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
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 hs WHERE hs.id = 123 AND hs.smth = 'blabla1' ) = 1, 'No expected id value in shadow table1';
    ASSERT EXISTS ( SELECT FROM hive.shadow_a_table1 hs WHERE hs.id = 123 AND hs.smth = 'blabla1' AND hive_block_num = 2 ), 'Wrong block num table1';
    ASSERT EXISTS ( SELECT FROM hive.shadow_a_table1 hs WHERE hs.id = 123 AND hs.smth = 'blabla1' AND hive_operation_type = 'INSERT' AND hive_operation_id = 1 ), 'Wrong operation type table1';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 ) = 1, 'Too many rows in shadow table1';

    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table2 hs WHERE hs.id = 223 AND hs.smth = 'blabla2' ) = 1, 'No expected id value in shadow table2';
    ASSERT EXISTS ( SELECT FROM hive.shadow_a_table2 hs WHERE hs.id = 223 AND hs.smth = 'blabla2' AND hive_block_num = 2 ), 'Wrong block num table2';
    ASSERT EXISTS ( SELECT FROM hive.shadow_a_table2 hs WHERE hs.id = 223 AND hs.smth = 'blabla2' AND hive_operation_type = 'INSERT' AND hive_operation_id = 1 ), 'Wrong operation type table2';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table2 ) = 1, 'Too many rows in shadow table1';

    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table3 hs WHERE hs.id = 323 AND hs.smth = 'blabla3' ) = 1, 'No expected id value in shadow table3';
    ASSERT EXISTS ( SELECT FROM hive.shadow_public_table3 hs WHERE hs.id = 323 AND hs.smth = 'blabla3' AND hive_block_num = 2 ), 'Wrong block num table3';
    ASSERT EXISTS ( SELECT FROM hive.shadow_public_table3 hs WHERE hs.id = 323 AND hs.smth = 'blabla3' AND hive_operation_type = 'INSERT' AND hive_operation_id = 1 ), 'Wrong operation type table3';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table3 ) = 1, 'Too many rows in shadow table1';
END
$BODY$
;




