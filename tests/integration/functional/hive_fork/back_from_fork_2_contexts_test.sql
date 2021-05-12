﻿DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.create_context( 'context' );
    CREATE TABLE table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.base );
    PERFORM hive.context_next_block( 'context' );
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla' );
    PERFORM hive.context_next_block( 'context' );

    PERFORM hive.create_context( 'context2' );
    CREATE TABLE table2( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.base );
    PERFORM hive.context_next_block( 'context2' );
    INSERT INTO table2( id, smth ) VALUES( 123, 'blabla' );
    PERFORM hive.context_next_block( 'context2' );

    TRUNCATE hive.shadow_public_table1; --to do not revert context inserts
    UPDATE table1 SET id=321;
    PERFORM hive.context_next_block( 'context' );
    DELETE FROM  table1 WHERE id=321;

    TRUNCATE hive.shadow_public_table2; --to do not revert context inserts
    UPDATE table2 SET id=321;
    PERFORM hive.context_next_block( 'context2' );
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
    PERFORM hive.back_context_from_fork(  'context'  );
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
    ASSERT ( SELECT COUNT(*) FROM table1 WHERE id=123 ) = 1, 'Updated row was not reverted';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 0, 'Shadow table is not empty';

    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table2 ) != 0, 'context2 shadow table was empty';
    ASSERT ( SELECT COUNT(*) FROM table2 WHERE id=321 ) = 1, 'Updated context2 row was reverted';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
