DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name = 'events_queue' ), 'No events_queue table';
    ASSERT ( SELECT COUNT(*) FROM hive.fork ) = 1, 'No default fork or to much forks by start';
END
$BODY$
;




