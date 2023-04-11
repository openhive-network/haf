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
    PERFORM hive.context_next_block( 'context' );
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
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla' );
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
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 hs WHERE hs.id = 123 AND hs.smth = 'blabla' ) = 1, 'No expected id value in shadow table';
    ASSERT EXISTS ( SELECT FROM hive.shadow_public_table1 hs WHERE hs.id = 123 AND hs.smth = 'blabla' AND hive_block_num = 2 ), 'Wrong block num';
    ASSERT EXISTS ( SELECT FROM hive.shadow_public_table1 hs WHERE hs.id = 123 AND hs.smth = 'blabla' AND hive_operation_type = 'INSERT' AND hive_operation_id = 1 ), 'Wrong operation type';
END
$BODY$
;




