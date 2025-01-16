﻿
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE TYPE custom_type AS (
        id INTEGER,
        val FLOAT,
        name TEXT
        );

    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE test.src_table(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type, name2 VARCHAR, num NUMERIC(3,2) ) INHERITS( a.context );

    PERFORM hive.context_next_block( 'context' );
    INSERT INTO test.src_table ( smth, name, values, data, name2, num )
    SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
    FROM generate_series(1, 10000) AS gen(id)
             JOIN ( VALUES( 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;

    PERFORM hive.context_next_block( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  StartTime timestamptz;
  EndTime timestamptz;
  Delta double precision;
BEGIN
    StartTime := clock_timestamp();
    FOR rowid IN 1..10000 LOOP
        UPDATE test.src_table SET name='changed' WHERE smth=rowid;
    END LOOP;
    EndTime := clock_timestamp();
    Delta := 1000 * ( extract(epoch from EndTime) - extract(epoch from StartTime) );
    RAISE NOTICE 'Duration in millisecs=%', Delta;
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM test.src_table WHERE name='changed' ) = 10000, 'Not all rows were updated';
END
$BODY$
;





