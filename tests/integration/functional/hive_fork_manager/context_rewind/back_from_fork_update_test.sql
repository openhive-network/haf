
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    CREATE TABLE table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.context );
    PERFORM hive.context_next_block( 'context' );
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla' );
    PERFORM hive.context_next_block( 'context' );
    TRUNCATE hive.shadow_public_table1; --to do not revert inserts
    UPDATE table1 SET id=321;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_back_from_fork( 'context' , -1 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM table1 WHERE id=123 ) = 1, 'Updated row was not reverted';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 0, 'Shadow table is not empty';
END
$BODY$
;




