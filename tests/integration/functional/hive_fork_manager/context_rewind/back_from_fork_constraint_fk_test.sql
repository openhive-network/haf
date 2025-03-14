﻿
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE table1( id INTEGER PRIMARY KEY, smth TEXT NOT NULL ) INHERITS( a.context );
    CREATE TABLE table2(
          id INTEGER NOT NULL
        , smth TEXT NOT NULL
        , table1_id INTEGER NOT NULL
        , CONSTRAINT fk_table2_table1_id FOREIGN KEY( table1_id ) REFERENCES table1(id) DEFERRABLE
    ) INHERITS( a.context );

    PERFORM hive.context_next_block( 'context' );

    -- one row inserted, ready to back from fork
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO table2( id, smth, table1_id ) VALUES( 223, 'blabla2', 123 );
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
    ASSERT ( SELECT COUNT(*) FROM table1 ) = 0, 'Inserted row was not removed table1';
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_public_table1 ) = 0, 'Shadow table is not empty table1';

    ASSERT ( SELECT COUNT(*) FROM table2 ) = 0, 'Inserted row was not removed table2';
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_public_table2 ) = 0, 'Shadow table is not empty table2';
END
$BODY$
;





