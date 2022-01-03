DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
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
    CREATE TABLE src_table(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type, name2 VARCHAR, num NUMERIC(3,2) ) INHERITS( hive.context );
    PERFORM hive.context_next_block( 'context' );
    INSERT INTO src_table ( smth, name, values, data, name2, num )
    VALUES( 1, 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) );

    PERFORM hive.context_next_block( 'context' );
    TRUNCATE hive.shadow_public_src_table; --to do not revert inserts
    UPDATE src_table SET name2='a';
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
    PERFORM hive.context_back_from_fork( 'context' , -1 );
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
    ASSERT ( SELECT COUNT(*) FROM src_table WHERE name2='padu' ) = 1, 'Updated row was not reverted';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_src_table ) = 0, 'Shadow table is not empty';
END
$BODY$
;





