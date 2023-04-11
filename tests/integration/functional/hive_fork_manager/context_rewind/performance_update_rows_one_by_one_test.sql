DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE TYPE custom_type AS (
        id INTEGER,
        val FLOAT,
        name TEXT
        );

    PERFORM hive.context_create( 'context' );
    CREATE TABLE hive.src_table(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type, name2 VARCHAR, num NUMERIC(3,2) ) INHERITS( hive.context );

    PERFORM hive.context_next_block( 'context' );
    INSERT INTO hive.src_table ( smth, name, values, data, name2, num )
    SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
    FROM generate_series(1, 10000) AS gen(id)
             JOIN ( VALUES( 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;

    PERFORM hive.context_next_block( 'context' );
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
DECLARE
  StartTime timestamptz;
  EndTime timestamptz;
  Delta double precision;
BEGIN
    StartTime := clock_timestamp();
    FOR rowid IN 1..10000 LOOP
        UPDATE hive.src_table SET name='changed' WHERE smth=rowid;
    END LOOP;
    EndTime := clock_timestamp();
    Delta := 1000 * ( extract(epoch from EndTime) - extract(epoch from StartTime) );
    RAISE NOTICE 'Duration in millisecs=%', Delta;
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hive.src_table WHERE name='changed' ) = 10000, 'Not all rows were updated';
END
$BODY$
;





