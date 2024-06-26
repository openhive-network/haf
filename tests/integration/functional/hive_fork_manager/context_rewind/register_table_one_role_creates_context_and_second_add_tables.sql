﻿CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 'a' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        CREATE TABLE table1( id SERIAL PRIMARY KEY, smth INTEGER, name TEXT ) INHERITS( a.context );
        ASSERT FALSE, 'Did not throw exception, haf_admin cannot register a table to an Alice''s context';
    EXCEPTION WHEN OTHERS THEN
        RETURN;
    END;
END;
$BODY$
;




