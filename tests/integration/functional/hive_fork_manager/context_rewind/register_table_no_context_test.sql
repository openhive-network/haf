CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        CREATE TABLE hive.table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( hive.context );
    EXCEPTION WHEN OTHERS THEN
        RETURN;
    END;

    ASSERT FALSE, 'Expected exception was not catched';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT * FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'table1' ), 'The table was created';
END
$BODY$
;




