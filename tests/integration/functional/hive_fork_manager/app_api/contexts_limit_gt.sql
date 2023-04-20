DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    BEGIN
        PERFORM hive.app_create_context( 'context_' || gen.* ) FROM generate_series(1, 1001) as gen;
        ASSERT FALSE, 'Exception was not raised';
    EXCEPTION WHEN OTHERS THEN
    END;
END
$BODY$
;