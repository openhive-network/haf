
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context' );
    CREATE TABLE A.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );
    PERFORM hive.context_next_block( 'context' );
    INSERT INTO A.table1( id, smth ) VALUES( 123, 'blabla' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_next_block( 'context' );
    UPDATE A.table1 SET id=321;
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 hs WHERE hs.id = 123 AND hs.smth = 'blabla' ) = 2, 'No expected id value in shadow table';
    ASSERT EXISTS ( SELECT FROM hive.shadow_a_table1 hs WHERE hs.id = 123 AND hs.smth = 'blabla' AND hive_block_num = 2 AND hive_operation_type = 'UPDATE' AND hive_operation_id = 2 ), 'No expected row';
END
$BODY$
;




