
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
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

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_next_block( 'context' );
    DELETE FROM A.table1;
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 hs WHERE hs.id = 123 AND hs.smth='balbla' ) = 2, 'No expected id value in shadow table';
    ASSERT EXISTS ( SELECT FROM hive.shadow_a_table1 hs WHERE hs.id = 123 AND hs.smth='balbla' AND hs.hive_block_num = 2 AND hs.hive_operation_type = 'DELETE' AND hive_operation_id = 2 ), 'Wrong block num';
END
$BODY$
;




