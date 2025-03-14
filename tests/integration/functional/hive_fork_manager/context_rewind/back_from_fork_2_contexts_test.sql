﻿
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE a.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( a.context );
    PERFORM hive.context_next_block( 'context' );
    INSERT INTO a.table1( id, smth ) VALUES( 123, 'blabla' );
    PERFORM hive.context_next_block( 'context' );

    PERFORM hive.context_create( 'context2', 'a' );
    CREATE TABLE a.table2( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( a.context2 );
    PERFORM hive.context_next_block( 'context2' );
    INSERT INTO a.table2( id, smth ) VALUES( 123, 'blabla' );
    PERFORM hive.context_next_block( 'context2' );

    TRUNCATE hafd.shadow_a_table1; --to do not revert context inserts
    UPDATE a.table1 SET id=321;
    PERFORM hive.context_next_block( 'context' );
    DELETE FROM  a.table1 WHERE id=321;

    TRUNCATE hafd.shadow_a_table2; --to do not revert context inserts
    UPDATE a.table2 SET id=321;
    PERFORM hive.context_next_block( 'context2' );
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
    ASSERT ( SELECT COUNT(*) FROM a.table1 WHERE id=123 ) = 1, 'Updated row was not reverted';
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_a_table1 ) = 0, 'Shadow table is not empty';

    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_a_table2 ) != 0, 'context2 shadow table was empty';
    ASSERT ( SELECT COUNT(*) FROM a.table2 WHERE id=321 ) = 1, 'Updated context2 row was reverted';
END
$BODY$
;




