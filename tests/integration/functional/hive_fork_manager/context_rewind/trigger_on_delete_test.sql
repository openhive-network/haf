DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context' );
    CREATE TABLE A.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );
    PERFORM hive.context_next_block( 'context' );
    INSERT INTO A.table1( id, smth ) VALUES( 123, 'balbla' );
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
    PERFORM hive.context_next_block( 'context' );
    DELETE FROM A.table1;
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
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 hs WHERE hs.id = 123 AND hs.smth='balbla' ) = 2, 'No expected id value in shadow table';
    ASSERT EXISTS ( SELECT FROM hive.shadow_a_table1 hs WHERE hs.id = 123 AND hs.smth='balbla' AND hs.hive_block_num = 2 AND hs.hive_operation_type = 'DELETE' AND hive_operation_id = 2 ), 'Wrong block num';
END
$BODY$
;




