﻿
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;

    CREATE TYPE custom_type AS (
        id INTEGER,
        val FLOAT,
        name TEXT
        );

    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE A.src_table(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type, name2 VARCHAR, num NUMERIC(3,2)  ) INHERITS( a.context );

    PERFORM hive.context_next_block( 'context' );
    INSERT INTO A.src_table ( smth, name, values, data, name2, num )
    VALUES( 1, 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) );

    PERFORM hive.context_next_block( 'context' );
    TRUNCATE hafd.shadow_a_src_table; --to do not revert inserts
    INSERT INTO A.src_table ( smth, name, values, data, name2, num )
    VALUES( 2, 'temp2', '{{0.25, 3.14, 16}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'abcd'::VARCHAR, 2.123::NUMERIC(3,2) );
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
    ASSERT ( SELECT COUNT(*) FROM A.src_table WHERE name2='padu' AND smth=1 ) = 1, 'Updated row was not reverted';
    ASSERT ( SELECT COUNT(*) FROM A.src_table ) = 1, 'Inserted row was not removed';
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_a_src_table ) = 0, 'Shadow table is not empty';
END
$BODY$
;





