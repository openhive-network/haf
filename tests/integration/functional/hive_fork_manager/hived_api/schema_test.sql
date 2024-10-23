CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name = 'events_queue' ), 'No events_queue table';
    ASSERT ( SELECT COUNT(*) FROM hafd.fork ) = 1, 'No default fork or to much forks by start';
END
$BODY$
;




