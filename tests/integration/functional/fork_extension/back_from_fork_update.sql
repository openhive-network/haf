﻿--Example of fork_extention usage
--The plugin has not been finished yet, and at the moment it can be only considered as a demo version to show its potential

--0. Load the extension plugin
LOAD '$libdir/plugins/libfork_extension.so';

DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    DROP TYPE IF EXISTS custom_type CASCADE;
    CREATE TYPE custom_type AS (
        id INTEGER,
        val FLOAT,
        name TEXT
        );
    -- a table with different kind of column types. It will be filled by the client
    DROP TABLE IF EXISTS src_table CASCADE;
    CREATE TABLE src_table(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type, name2 VARCHAR, num NUMERIC(3,2) );

    -- a table to save origin values
    DROP TABLE IF EXISTS src_table_pattern CASCADE;
    CREATE TABLE src_table_pattern(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type, name2 VARCHAR, num NUMERIC(3,2) );

    INSERT INTO src_table ( smth, name, values, data, name2, num )
    SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
    FROM generate_series(1, 10000) AS gen(id)
             JOIN ( VALUES( 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;

    INSERT INTO src_table_pattern SELECT * FROM src_table;

    -- Create trigger ( function hive_on_table_change()  was added by the plugin during loading )
    CREATE TRIGGER on_src_table_change AFTER UPDATE ON src_table
        REFERENCING NEW TABLE AS new_table OLD TABLE AS old_table
        FOR EACH STATEMENT EXECUTE PROCEDURE hive_on_table_change();

    -- Make operations on src_table update rows
    UPDATE src_table SET name = 'changed name';

    ASSERT EXISTS ( SELECT * FROM src_table_pattern EXCEPT SELECT * FROM src_table ) = TRUE, 'ERROR: Changed table is the same as pattern';
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- back from fork - revert all the insersts above
    PERFORM hive_back_from_fork();
END
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT * FROM src_table_pattern EXCEPT SELECT * FROM src_table ) = FALSE, 'TEST FAILED';
END
$BODY$
;


SELECT test_given();
SELECT test_when();
SELECT test_then();

