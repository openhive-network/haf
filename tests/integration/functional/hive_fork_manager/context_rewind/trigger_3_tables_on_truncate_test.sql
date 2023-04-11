DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );

    CREATE TABLE table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );
    CREATE TABLE table2( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );
    CREATE TABLE table3( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );

    PERFORM hive.context_next_block( 'context' );

    INSERT INTO table1( id, smth ) VALUES( 123, 'balbla1' );
    INSERT INTO table2( id, smth ) VALUES( 223, 'balbla2' );
    INSERT INTO table3( id, smth ) VALUES( 323, 'balbla3' );

    PERFORM hive.context_next_block( 'context' );
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
    TRUNCATE table1;
    TRUNCATE table2;
    TRUNCATE table3;
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
    ASSERT EXISTS ( SELECT FROM hive.shadow_public_table1 hs WHERE hs.id = 123 AND hs.smth='balbla1' AND hive_operation_type = 'DELETE' AND hive_rowid = 1 AND hive_block_num = 2 AND hive_operation_id = 2 ), 'Lack of expected operation table1';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 2, 'Too many rows in shadow table1';

    ASSERT EXISTS ( SELECT FROM hive.shadow_public_table2 hs WHERE hs.id = 223 AND hs.smth='balbla2' AND hive_operation_type = 'DELETE' AND hive_rowid = 1  AND hive_block_num = 2 AND hive_operation_id = 2 ), 'Lack of expected operation table2';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 2, 'Too many rows in shadow table2';

    ASSERT EXISTS ( SELECT FROM hive.shadow_public_table3 hs WHERE hs.id = 323 AND hs.smth='balbla3' AND hive_operation_type = 'DELETE' AND hive_rowid = 1  AND hive_block_num = 2 AND hive_operation_id = 2 ), 'Lack of expected operation table3';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 2, 'Too many rows in shadow table3';
END
$BODY$
;




