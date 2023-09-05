CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$

BEGIN
    BEGIN
        PERFORM hive.context_create( 'context_' || gen.* ) FROM generate_series(1, 1001) as gen;
        ASSERT FALSE, 'Exception was not raised';
    EXCEPTION WHEN OTHERS THEN
    END;
END
$BODY$
;