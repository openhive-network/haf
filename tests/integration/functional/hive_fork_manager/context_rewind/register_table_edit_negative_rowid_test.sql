
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    CREATE TABLE table1( id SERIAL PRIMARY KEY, smth INTEGER, name TEXT ) INHERITS( hive.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        ALTER TABLE table1 DROP COLUMN hive_rowid;
    EXCEPTION WHEN OTHERS THEN
        RETURN;
    END;

    ASSERT FALSE, 'Did not catch expected exception';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS(
        SELECT * FROM information_schema.columns iss WHERE iss.table_name='table1' AND iss.column_name='test_column'
        )
        , 'Column was inserted'
    ;
END;
$BODY$
;




