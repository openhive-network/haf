﻿
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    CREATE SCHEMA B;

    PERFORM hive.context_create( 'context', 'a' );

    CREATE TABLE A.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( a.context );
    CREATE TABLE B.table2( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( a.context );
    CREATE TABLE table3( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( a.context );

    PERFORM hive.context_next_block( 'context' );

    INSERT INTO A.table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO B.table2( id, smth ) VALUES( 223, 'blabla2' );
    INSERT INTO table3( id, smth ) VALUES( 323, 'blabla3' );

    PERFORM hive.context_next_block( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    UPDATE A.table1 SET smth='a1';
    UPDATE B.table2 SET smth='a2';
    UPDATE table3 SET smth='a3';
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_a_table1 hs WHERE hs.id = 123 AND hs.smth = 'blabla1' AND hs.hive_rowid=1 AND hs.hive_operation_type='UPDATE' AND hive_operation_id = 2 ) = 1, 'No expected id value in shadow table1';
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_a_table1 ) = 2, 'Too many rows in shadow table1';

    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_b_table2 hs WHERE hs.id = 223 AND hs.smth = 'blabla2' AND hs.hive_rowid=1 AND hs.hive_operation_type='UPDATE' AND hive_operation_id = 2 ) = 1, 'No expected id value in shadow table2';
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_b_table2 ) = 2, 'Too many rows in shadow table2';

    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_public_table3 hs WHERE hs.id = 323 AND hs.smth = 'blabla3' AND hs.hive_rowid=1 AND hs.hive_operation_type='UPDATE' AND hive_operation_id = 2 ) = 1, 'No expected id value in shadow table2';
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_public_table3 ) = 2, 'Too many rows in shadow table3';
END
$BODY$
;




