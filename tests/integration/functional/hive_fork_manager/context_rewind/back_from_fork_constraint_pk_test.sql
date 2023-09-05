
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    CREATE TABLE table1(
          id INTEGER NOT NULL
        , smth TEXT NOT NULL
        , CONSTRAINT pk_table1 PRIMARY KEY ( smth )
    ) INHERITS( hive.context );

    PERFORM hive.context_next_block( 'context' );
    INSERT INTO table1( id, smth ) VALUES( 1, 'A' );
    INSERT INTO table1( id, smth ) VALUES( 2, 'B' );

    TRUNCATE hive.shadow_public_table1; --to do not revert inserts

    DELETE FROM table1 WHERE id=1;
    UPDATE table1 SET id=1 WHERE id=2;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- because table1 will be first rewinded table2 will stay with incorrect FK for tabe1(id)
    PERFORM hive.context_back_from_fork( 'context' , -1 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM table1 ) = 2, 'Deleted row was not reinserted';
    ASSERT EXISTS ( SELECT FROM table1 WHERE id=1 AND smth='A' ), 'First row was not restored';
    ASSERT EXISTS ( SELECT FROM table1 WHERE id=2 AND smth='B' ), 'Second row was not restored';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 0, 'Shadow table is not empty';
END
$BODY$
;





