DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name = 'contexts' ), 'No contexts table';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name = 'registered_tables' ), 'No registered_tables table';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'triggers' ), 'No triggers table';
END
$BODY$
;




