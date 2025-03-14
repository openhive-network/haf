﻿
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE test.table1( id SERIAL PRIMARY KEY, smth INTEGER, name TEXT ) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    DROP TABLE test.table1;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- we only noticed about rmoving registered table, there is no possibility to prevent DROP a table
    -- because  event trigger 'sql drop' arrives at the moment when the table is already removed.
    -- This sitation should not bother us, since we want to register table with CREATE TABLE command, so DROP is
    -- a good choice to make unregister
    ASSERT NOT EXISTS(
        SELECT * FROM information_schema.columns iss WHERE iss.table_name='table1'
        )
        , 'Table was removed'
    ;
END;
$BODY$
;




