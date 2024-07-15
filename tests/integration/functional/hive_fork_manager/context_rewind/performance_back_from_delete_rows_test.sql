﻿
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE TYPE custom_type AS (
        id INTEGER,
        val FLOAT,
        name hive.ctext
        );

    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE src_table(id  SERIAL PRIMARY KEY, smth INTEGER, name hive.ctext, values FLOAT[], data custom_type, name2 VARCHAR COLLATE "C", num NUMERIC(3,2) ) INHERITS( a.context );

    PERFORM hive.context_next_block( 'context' );
    INSERT INTO src_table ( smth, name, values, data, name2, num )
    SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
    FROM generate_series(1, 10000) AS gen(id)
             JOIN ( VALUES( 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR COLLATE "C", 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;


    TRUNCATE hive.shadow_public_src_table; --to do not revert inserts
    PERFORM hive.context_next_block( 'context' );
    DELETE FROM src_table;
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
    PERFORM hive.context_back_from_fork( 'context' , -1 );
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
    ASSERT ( SELECT COUNT(*) FROM src_table ) = 10000, 'Not all rows were re-inserted';
END
$BODY$
;





